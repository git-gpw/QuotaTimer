import Foundation

public enum UsageAPIError: Error, CustomStringConvertible {
    case unauthorized
    case rateLimited(retryAfterSeconds: Int?)
    case httpError(statusCode: Int, body: String)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)

    public var description: String {
        switch self {
        case .unauthorized:
            return "401 Unauthorized — token may be expired or invalid"
        case .rateLimited(let retry):
            if let s = retry {
                return "429 Rate Limited — retry after \(s)s"
            }
            return "429 Rate Limited"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body.prefix(200))"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        case .decodingError(let err):
            return "Failed to decode response: \(err)"
        }
    }
}

public struct UsageAPIClient: Sendable {
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    public init() {}

    public func fetch(token: String) async throws -> UsageResponse {
        var request = URLRequest(url: Self.endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageAPIError.networkError(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw UsageAPIError.networkError(underlying: URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200:
            break
        case 401:
            throw UsageAPIError.unauthorized
        case 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After")
                .flatMap(Int.init)
            throw UsageAPIError.rateLimited(retryAfterSeconds: retry)
        default:
            let body = String(data: data, encoding: .utf8) ?? "(non-UTF8)"
            throw UsageAPIError.httpError(statusCode: http.statusCode, body: body)
        }

        do {
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            throw UsageAPIError.decodingError(underlying: error)
        }
    }
}

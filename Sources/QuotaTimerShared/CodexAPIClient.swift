import Foundation

public struct CodexAPIClient: Sendable {
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    public init() {}

    public func fetch(credential: CodexCredential) async throws -> CodexUsageResponse {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credential.accountId, forHTTPHeaderField: "ChatGPT-Account-Id")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CodexAuthError.parseError("Network error: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw CodexAuthError.parseError("Non-HTTP response")
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(CodexUsageResponse.self, from: data)
        case 401, 403:
            throw CodexAuthError.tokenExpired
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw CodexAuthError.parseError("HTTP \(http.statusCode): \(body.prefix(200))")
        }
    }
}

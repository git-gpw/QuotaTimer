import Foundation

public struct CodexCredential: Sendable {
    public let accessToken: String
    public let accountId: String
}

public enum CodexAuthError: Error, CustomStringConvertible, Sendable {
    case fileNotFound
    case parseError(String)
    case missingFields
    case tokenExpired

    public var description: String {
        switch self {
        case .fileNotFound: return "~/.codex/auth.json not found"
        case .parseError(let msg): return "Auth parse error: \(msg)"
        case .missingFields: return "Missing access token or account ID in auth.json"
        case .tokenExpired: return "Codex token expired — run `codex` to re-authenticate"
        }
    }
}

public struct CodexAuthReader: Sendable {
    public init() {}

    private var authFilePath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.codex/auth.json"
    }

    public func read() throws -> CodexCredential {
        return try readFromFile(path: authFilePath)
    }

    public func readFromFile(path: String) throws -> CodexCredential {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CodexAuthError.fileNotFound
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try parseAuthJSON(data)
    }

    public func parseAuthJSON(_ data: Data) throws -> CodexCredential {
        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CodexAuthError.parseError("Not a JSON object")
            }
            json = parsed
        } catch let err as CodexAuthError {
            throw err
        } catch {
            throw CodexAuthError.parseError(error.localizedDescription)
        }

        let accessToken: String
        let accountId: String

        if let tokens = json["tokens"] as? [String: Any] {
            guard let token = tokens["access_token"] as? String,
                  let account = tokens["account_id"] as? String else {
                throw CodexAuthError.missingFields
            }
            accessToken = token
            accountId = account
        } else if let token = json["access"] as? String,
                  let account = json["accountId"] as? String {
            accessToken = token
            accountId = account
        } else {
            throw CodexAuthError.missingFields
        }

        guard !accessToken.isEmpty else {
            throw CodexAuthError.missingFields
        }

        if let expires = json["expires"] as? Double {
            let expiresAt = Date(timeIntervalSince1970: expires / 1000)
            if expiresAt < Date() {
                throw CodexAuthError.tokenExpired
            }
        }

        return CodexCredential(accessToken: accessToken, accountId: accountId)
    }
}

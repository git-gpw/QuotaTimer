import Foundation

public enum CredentialStatus: Sendable, Equatable {
    case connected(expiresAt: Date?)
    case expired(at: Date?)
    case notFound(hint: String)
    case error(String)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

public struct CredentialChecker: Sendable {
    public init() {}

    public func checkClaude() -> CredentialStatus {
        do {
            let cred = try KeychainReader().readCredential()
            return .connected(expiresAt: cred.expiresAt)
        } catch let err as KeychainError {
            switch err {
            case .tokenExpired(let date):
                return .expired(at: date)
            case .itemNotFound:
                return .notFound(hint: "Run `claude` in Terminal to log in")
            case .missingOAuthFields:
                return .notFound(hint: "Run `claude` in Terminal to log in")
            default:
                return .error(err.description)
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }

    public func checkCodex() -> CredentialStatus {
        do {
            _ = try CodexAuthReader().read()
            return .connected(expiresAt: nil)
        } catch let err as CodexAuthError {
            switch err {
            case .tokenExpired:
                return .expired(at: nil)
            case .fileNotFound:
                return .notFound(hint: "Run `codex` in Terminal to log in")
            case .missingFields:
                return .notFound(hint: "Run `codex` in Terminal to log in")
            case .parseError(let msg):
                return .error(msg)
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }
}

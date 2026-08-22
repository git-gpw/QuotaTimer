import Foundation
import Security

public enum KeychainError: Error, CustomStringConvertible {
    case itemNotFound
    case unexpectedData
    case jsonParseError(underlying: Error)
    case missingOAuthFields
    case tokenExpired(expiresAt: Date)
    case securityError(OSStatus)

    public var description: String {
        switch self {
        case .itemNotFound:
            return "Keychain item 'Claude Code-credentials' not found"
        case .unexpectedData:
            return "Keychain item is not a valid UTF-8 string"
        case .jsonParseError(let err):
            return "Failed to parse keychain JSON: \(err)"
        case .missingOAuthFields:
            return "JSON missing claudeAiOauth.accessToken or expiresAt"
        case .tokenExpired(let date):
            return "Token expired at \(date)"
        case .securityError(let status):
            return "Keychain error: \(status)"
        }
    }

    var isTokenExpired: Bool {
        if case .tokenExpired = self { return true }
        return false
    }
}

public struct OAuthCredential: Sendable {
    public let accessToken: String
    public let expiresAt: Date
}

public struct KeychainReader: Sendable {
    private static let serviceName = "Claude Code-credentials"

    public init() {}

    public func readCredential() throws -> OAuthCredential {
        do {
            return try readViaSecurityCLI()
        } catch let err as KeychainError where err.isTokenExpired {
            throw err
        } catch {}
        do {
            return try readFromCredentialsFile()
        } catch let err as KeychainError where err.isTokenExpired {
            throw err
        } catch {}
        return try readViaSecurityFramework()
    }

    private func readViaSecurityCLI() throws -> OAuthCredential {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", Self.serviceName, "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw KeychainError.itemNotFound
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonString = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !jsonString.isEmpty else {
            throw KeychainError.unexpectedData
        }

        return try parseCredentialJSON(jsonString)
    }

    private func readFromCredentialsFile() throws -> OAuthCredential {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        let data = try Data(contentsOf: path)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return try parseCredentialJSON(jsonString)
    }

    private func readViaSecurityFramework() throws -> OAuthCredential {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        guard status == errSecSuccess else {
            throw KeychainError.securityError(status)
        }
        guard let data = result as? Data,
              let jsonString = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return try parseCredentialJSON(jsonString)
    }

    public func parseCredentialJSON(_ jsonString: String) throws -> OAuthCredential {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: Data(jsonString.utf8))
        } catch {
            throw KeychainError.jsonParseError(underlying: error)
        }

        guard let root = parsed as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              let expiresAtMs = oauth["expiresAt"] as? Double else {
            throw KeychainError.missingOAuthFields
        }

        let expiresAt = Date(timeIntervalSince1970: expiresAtMs / 1000.0)
        if expiresAt < Date() {
            throw KeychainError.tokenExpired(expiresAt: expiresAt)
        }

        return OAuthCredential(accessToken: token, expiresAt: expiresAt)
    }
}

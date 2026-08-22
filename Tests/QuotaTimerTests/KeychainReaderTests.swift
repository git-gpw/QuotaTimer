import XCTest
@testable import QuotaTimerShared

final class KeychainReaderTests: XCTestCase {

    private let reader = KeychainReader()

    private func loadFixture(_ name: String) throws -> String {
        let url = Bundle(for: type(of: self))
            .url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testParseValidCredential() throws {
        let json = try loadFixture("credential_valid")
        let cred = try reader.parseCredentialJSON(json)

        XCTAssertEqual(cred.accessToken, "test-token-abc123")
        XCTAssertTrue(cred.expiresAt > Date(), "Token should not be expired (fixture expires in 2099)")
    }

    func testParseExpiredCredentialThrows() throws {
        let json = try loadFixture("credential_expired")

        XCTAssertThrowsError(try reader.parseCredentialJSON(json)) { error in
            guard case KeychainError.tokenExpired = error else {
                XCTFail("Expected KeychainError.tokenExpired, got \(error)")
                return
            }
        }
    }

    func testParseMissingFieldsThrows() throws {
        let json = try loadFixture("credential_missing_fields")

        XCTAssertThrowsError(try reader.parseCredentialJSON(json)) { error in
            guard case KeychainError.missingOAuthFields = error else {
                XCTFail("Expected KeychainError.missingOAuthFields, got \(error)")
                return
            }
        }
    }

    func testParseGarbageJSONThrows() {
        XCTAssertThrowsError(try reader.parseCredentialJSON("not valid json")) { error in
            guard case KeychainError.jsonParseError = error else {
                XCTFail("Expected KeychainError.jsonParseError, got \(error)")
                return
            }
        }
    }
}

import XCTest
@testable import QuotaTimerShared

final class UsageResponseTests: XCTestCase {

    private func loadFixture(_ name: String) throws -> Data {
        let url = Bundle(for: type(of: self))
            .url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }

    func testDecodeSuccess() throws {
        let data = try loadFixture("usage_success")
        let response = try JSONDecoder().decode(UsageResponse.self, from: data)

        XCTAssertEqual(response.fiveHour?.utilization, 42.0)
        XCTAssertEqual(response.fiveHour?.resetsAt, "2025-06-10T14:30:00Z")
        XCTAssertEqual(response.sevenDay?.utilization, 65.0)
        XCTAssertEqual(response.sevenDayOpus?.utilization, 30.0)
        XCTAssertEqual(response.sevenDaySonnet?.utilization, 50.0)
        XCTAssertEqual(response.sevenDayDesign?.utilization, 0.0)
        XCTAssertEqual(response.sevenDayFable?.utilization, 0.0)
        XCTAssertNil(response.sevenDayFable?.resetsAt)
        XCTAssertNil(response.nimbus_quill)

        let limits = try XCTUnwrap(response.limits)
        XCTAssertEqual(limits.count, 3)
        XCTAssertEqual(limits[0].kind, "session")
        XCTAssertEqual(limits[0].group, "session")
        XCTAssertEqual(limits[0].percent, 42)
        XCTAssertEqual(limits[0].isActive, true)
        XCTAssertEqual(limits[0].scope?.model?.id, "claude-opus-4")
        XCTAssertEqual(limits[0].scope?.model?.displayName, "Claude Opus 4")
        XCTAssertEqual(limits[1].kind, "weekly_all")
        XCTAssertNil(limits[1].scope)
        XCTAssertNil(limits[2].scope?.model?.id)
        XCTAssertEqual(limits[2].scope?.model?.displayName, "Fable")
        XCTAssertNil(limits[2].resetsAt)
    }

    func testDecodeEmptyLimits() throws {
        let data = try loadFixture("usage_empty_limits")
        let response = try JSONDecoder().decode(UsageResponse.self, from: data)

        XCTAssertEqual(response.fiveHour?.utilization, 0.0)
        XCTAssertNil(response.fiveHour?.resetsAt)
        XCTAssertEqual(response.sevenDay?.utilization, 2.0)
        XCTAssertEqual(response.limits?.count, 0)
        XCTAssertNil(response.sevenDayOpus)
        XCTAssertNil(response.sevenDaySonnet)
    }

    func testDecodeMinimalPayload() throws {
        let data = try loadFixture("usage_minimal")
        let response = try JSONDecoder().decode(UsageResponse.self, from: data)

        XCTAssertEqual(response.fiveHour?.utilization, 0.99)
        XCTAssertNil(response.sevenDay)
        XCTAssertNil(response.limits)
    }

    func testDecodeMalformedThrows() throws {
        let data = try loadFixture("usage_malformed")
        XCTAssertThrowsError(try JSONDecoder().decode(UsageResponse.self, from: data))
    }

    func testDecodeGarbageThrows() {
        let data = Data("not json at all".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(UsageResponse.self, from: data))
    }
}

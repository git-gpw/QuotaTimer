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

        XCTAssertEqual(response.fiveHour?.utilization, 0.42)
        XCTAssertEqual(response.fiveHour?.resetsAt, "2025-06-10T14:30:00Z")
        XCTAssertEqual(response.sevenDay?.utilization, 0.65)
        XCTAssertEqual(response.sevenDayOpus?.utilization, 0.3)
        XCTAssertEqual(response.sevenDaySonnet?.utilization, 0.5)
        XCTAssertEqual(response.sevenDayDesign?.utilization, 0.0)
        XCTAssertEqual(response.sevenDayFable?.utilization, 0.0)

        let limits = try XCTUnwrap(response.limits)
        XCTAssertEqual(limits.count, 2)
        XCTAssertEqual(limits[0].kind, "five_hour")
        XCTAssertEqual(limits[0].percent, 0.42)
        XCTAssertEqual(limits[0].scope?.model?.id, "claude-opus-4")
        XCTAssertEqual(limits[0].scope?.model?.displayName, "Claude Opus 4")
        XCTAssertEqual(limits[1].kind, "seven_day")
        XCTAssertEqual(limits[1].scope?.model?.id, "claude-sonnet-4")
    }

    func testDecodeEmptyLimits() throws {
        let data = try loadFixture("usage_empty_limits")
        let response = try JSONDecoder().decode(UsageResponse.self, from: data)

        XCTAssertEqual(response.fiveHour?.utilization, 0.0)
        XCTAssertEqual(response.sevenDay?.utilization, 0.0)
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

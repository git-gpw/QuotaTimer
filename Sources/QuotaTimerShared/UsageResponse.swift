import Foundation

public struct UsageResponse: Codable, Sendable {
    public let fiveHour: UsageWindow?
    public let sevenDay: UsageWindow?
    public let sevenDayOpus: UsageWindow?
    public let sevenDaySonnet: UsageWindow?
    public let sevenDayDesign: UsageWindow?
    public let sevenDayFable: UsageWindow?
    public let limits: [UsageLimit]?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayDesign = "seven_day_design"
        case sevenDayFable = "seven_day_fable"
        case limits
    }
}

public struct UsageWindow: Codable, Sendable {
    public let utilization: Double
    public let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

public struct UsageLimit: Codable, Sendable {
    public let kind: String
    public let percent: Double
    public let resetsAt: String
    public let scope: UsageLimitScope?

    enum CodingKeys: String, CodingKey {
        case kind, percent
        case resetsAt = "resets_at"
        case scope
    }
}

public struct UsageLimitScope: Codable, Sendable {
    public let model: UsageLimitModel?
}

public struct UsageLimitModel: Codable, Sendable {
    public let id: String
    public let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

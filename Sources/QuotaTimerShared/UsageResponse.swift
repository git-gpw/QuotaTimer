import Foundation

public struct UsageResponse: Sendable {
    public let fiveHour: UsageWindow?
    public let sevenDay: UsageWindow?
    public let sevenDayOpus: UsageWindow?
    public let sevenDaySonnet: UsageWindow?
    public let sevenDayDesign: UsageWindow?
    public let sevenDayFable: UsageWindow?
    public let sevenDayCowork: UsageWindow?
    public let sevenDayOmelette: UsageWindow?
    public let nimbus_quill: UsageWindow?
    public let limits: [UsageLimit]?
}

extension UsageResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayDesign = "seven_day_design"
        case sevenDayFable = "seven_day_fable"
        case sevenDayCowork = "seven_day_cowork"
        case sevenDayOmelette = "seven_day_omelette"
        case nimbus_quill
        case limits
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try c.decodeIfPresent(UsageWindow.self, forKey: .fiveHour)
        sevenDay = try c.decodeIfPresent(UsageWindow.self, forKey: .sevenDay)
        sevenDayOpus = try c.decodeIfPresent(UsageWindow.self, forKey: .sevenDayOpus)
        sevenDaySonnet = try c.decodeIfPresent(UsageWindow.self, forKey: .sevenDaySonnet)
        sevenDayDesign = try c.decodeIfPresent(UsageWindow.self, forKey: .sevenDayDesign)
        sevenDayFable = try c.decodeIfPresent(UsageWindow.self, forKey: .sevenDayFable)
        sevenDayCowork = try c.decodeIfPresent(UsageWindow.self, forKey: .sevenDayCowork)
        sevenDayOmelette = try c.decodeIfPresent(UsageWindow.self, forKey: .sevenDayOmelette)
        nimbus_quill = try c.decodeIfPresent(UsageWindow.self, forKey: .nimbus_quill)
        limits = try c.decodeIfPresent([UsageLimit].self, forKey: .limits)
    }
}

public struct UsageWindow: Codable, Sendable {
    public let utilization: Double
    public let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

public struct UsageLimit: Codable, Sendable {
    public let kind: String
    public let percent: Double
    public let resetsAt: String?
    public let scope: UsageLimitScope?
    public let group: String?
    public let severity: String?
    public let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case kind, percent
        case resetsAt = "resets_at"
        case scope, group, severity
        case isActive = "is_active"
    }
}

public struct UsageLimitScope: Codable, Sendable {
    public let model: UsageLimitModel?
}

public struct UsageLimitModel: Codable, Sendable {
    public let id: String?
    public let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

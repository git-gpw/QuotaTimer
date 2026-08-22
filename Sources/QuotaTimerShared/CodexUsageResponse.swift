import Foundation

public struct CodexUsageResponse: Codable, Sendable {
    public let planType: String?
    public let rateLimit: CodexRateLimit?
    public let additionalRateLimits: [CodexAdditionalLimit]?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case additionalRateLimits = "additional_rate_limits"
    }
}

public struct CodexRateLimit: Codable, Sendable {
    public let allowed: Bool?
    public let limitReached: Bool?
    public let primaryWindow: CodexWindow?
    public let secondaryWindow: CodexWindow?

    enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached = "limit_reached"
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

public struct CodexWindow: Codable, Sendable {
    public let usedPercent: Double
    public let limitWindowSeconds: Int?
    public let resetAfterSeconds: Int?
    public let resetAt: Double

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }
}

public struct CodexAdditionalLimit: Codable, Sendable {
    public let limitName: String?
    public let meteredFeature: String?
    public let rateLimit: CodexAdditionalRateLimit?

    enum CodingKeys: String, CodingKey {
        case limitName = "limit_name"
        case meteredFeature = "metered_feature"
        case rateLimit = "rate_limit"
    }
}

public struct CodexAdditionalRateLimit: Codable, Sendable {
    public let primaryWindow: CodexWindow?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
    }
}

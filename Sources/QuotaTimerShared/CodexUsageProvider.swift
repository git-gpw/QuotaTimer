import Foundation

public struct CodexUsageProvider: UsageProvider {
    public let id = "codex"
    public let displayName = "Codex"

    private let authReader = CodexAuthReader()
    private let apiClient = CodexAPIClient()

    public init() {}

    public func fetch() async throws -> [UsageWindowInfo] {
        let credential = try authReader.read()
        let response = try await apiClient.fetch(credential: credential)
        return Self.mapResponse(response)
    }

    public static func mapResponse(_ response: CodexUsageResponse) -> [UsageWindowInfo] {
        guard let rateLimit = response.rateLimit else { return [] }

        var windows: [UsageWindowInfo] = []

        if let primary = rateLimit.primaryWindow {
            let label = windowLabel(seconds: primary.limitWindowSeconds)
            let kind = windowKind(seconds: primary.limitWindowSeconds)
            windows.append(UsageWindowInfo(
                id: "codex-primary",
                kind: kind,
                label: label,
                usedFraction: primary.usedPercent / 100.0,
                resetsAt: Date(timeIntervalSince1970: primary.resetAt),
                perModel: mapAdditionalLimits(response.additionalRateLimits)
            ))
        }

        if let secondary = rateLimit.secondaryWindow {
            let label = windowLabel(seconds: secondary.limitWindowSeconds)
            let kind = windowKind(seconds: secondary.limitWindowSeconds)
            windows.append(UsageWindowInfo(
                id: "codex-secondary",
                kind: kind,
                label: label,
                usedFraction: secondary.usedPercent / 100.0,
                resetsAt: Date(timeIntervalSince1970: secondary.resetAt)
            ))
        }

        return windows
    }

    private static func windowLabel(seconds: Int?) -> String {
        guard let seconds else { return "Rate limit" }
        switch seconds {
        case ..<21600: return "5-hour session"
        case ..<604800: return "Daily limit"
        default: return "Weekly limit"
        }
    }

    private static func windowKind(seconds: Int?) -> UsageWindowKind {
        guard let seconds else { return .session }
        switch seconds {
        case ..<21600: return .session
        default: return .weekly
        }
    }

    private static func mapAdditionalLimits(_ limits: [CodexAdditionalLimit]?) -> [ModelUsage]? {
        guard let limits, !limits.isEmpty else { return nil }

        let models = limits.compactMap { limit -> ModelUsage? in
            guard let window = limit.rateLimit?.primaryWindow else { return nil }
            let name = limit.limitName ?? limit.meteredFeature ?? "Unknown"
            return ModelUsage(
                id: limit.meteredFeature ?? name,
                displayName: name,
                usedFraction: window.usedPercent / 100.0,
                resetsAt: Date(timeIntervalSince1970: window.resetAt)
            )
        }

        return models.isEmpty ? nil : models
    }
}

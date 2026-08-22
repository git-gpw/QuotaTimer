import Foundation

public struct ClaudeUsageProvider: UsageProvider {
    public let id = "claude"
    public let displayName = "Claude"

    private let keychainReader: KeychainReader
    private let apiClient: UsageAPIClient

    public init(keychainReader: KeychainReader = KeychainReader(), apiClient: UsageAPIClient = UsageAPIClient()) {
        self.keychainReader = keychainReader
        self.apiClient = apiClient
    }

    public func fetch() async throws -> [UsageWindowInfo] {
        let credential = try keychainReader.readCredential()
        let response = try await apiClient.fetch(token: credential.accessToken)
        return Self.mapResponse(response)
    }

    public static func mapResponse(_ response: UsageResponse) -> [UsageWindowInfo] {
        var windows: [UsageWindowInfo] = []

        if let fh = response.fiveHour {
            let date = fh.resetsAt.flatMap(parseISO8601) ?? Date().addingTimeInterval(5 * 3600)
            let perModel = extractPerModelUsage(from: response.limits, group: "session")
            windows.append(UsageWindowInfo(
                id: "claude-session",
                kind: .session,
                label: "5-hour session",
                usedFraction: normalizePct(fh.utilization),
                resetsAt: date,
                perModel: perModel.isEmpty ? nil : perModel
            ))
        }

        if let sd = response.sevenDay {
            let date = sd.resetsAt.flatMap(parseISO8601) ?? Date().addingTimeInterval(7 * 86400)
            var perModel: [ModelUsage] = []
            perModel.append(contentsOf: modelWindow("Opus", response.sevenDayOpus))
            perModel.append(contentsOf: modelWindow("Sonnet", response.sevenDaySonnet))
            perModel.append(contentsOf: modelWindow("Fable", response.sevenDayFable))
            perModel.append(contentsOf: modelWindow("Design", response.sevenDayDesign))
            perModel.append(contentsOf: modelWindow("Cowork", response.sevenDayCowork))
            perModel.append(contentsOf: modelWindow("Omelette", response.sevenDayOmelette))

            windows.append(UsageWindowInfo(
                id: "claude-weekly",
                kind: .weekly,
                label: "7-day total",
                usedFraction: normalizePct(sd.utilization),
                resetsAt: date,
                perModel: perModel.isEmpty ? nil : perModel
            ))
        }

        return windows
    }

    private static func modelWindow(_ name: String, _ window: UsageWindow?) -> [ModelUsage] {
        guard let w = window else { return [] }
        let date = w.resetsAt.flatMap(parseISO8601) ?? Date().addingTimeInterval(7 * 86400)
        return [ModelUsage(
            id: "claude-weekly-\(name.lowercased())",
            displayName: name,
            usedFraction: normalizePct(w.utilization),
            resetsAt: date
        )]
    }

    private static func extractPerModelUsage(from limits: [UsageLimit]?, group: String) -> [ModelUsage] {
        guard let limits else { return [] }
        return limits.compactMap { limit -> ModelUsage? in
            guard limit.group == group || limit.kind == group,
                  let model = limit.scope?.model else { return nil }
            let date = limit.resetsAt.flatMap(parseISO8601) ?? Date().addingTimeInterval(5 * 3600)
            return ModelUsage(
                id: "claude-\(group)-\(model.id ?? model.displayName.lowercased())",
                displayName: model.displayName,
                usedFraction: normalizePct(limit.percent),
                resetsAt: date
            )
        }
    }

    private static func normalizePct(_ value: Double) -> Double {
        if value > 1 { return value / 100.0 }
        return value
    }

    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let iso8601FallbackFormatter = ISO8601DateFormatter()

    private static func parseISO8601(_ string: String) -> Date? {
        iso8601Formatter.date(from: string) ?? iso8601FallbackFormatter.date(from: string)
    }
}

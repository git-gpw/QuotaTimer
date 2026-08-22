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

        if let fh = response.fiveHour, let date = parseISO8601(fh.resetsAt) {
            let perModel = extractPerModelUsage(from: response.limits, kind: "five_hour")
            windows.append(UsageWindowInfo(
                id: "claude-session",
                kind: .session,
                label: "5-hour session",
                usedFraction: fh.utilization,
                resetsAt: date,
                perModel: perModel.isEmpty ? nil : perModel
            ))
        }

        if let sd = response.sevenDay, let date = parseISO8601(sd.resetsAt) {
            var perModel: [ModelUsage] = []
            perModel.append(contentsOf: modelWindow("Opus", response.sevenDayOpus))
            perModel.append(contentsOf: modelWindow("Sonnet", response.sevenDaySonnet))
            perModel.append(contentsOf: modelWindow("Fable", response.sevenDayFable))
            perModel.append(contentsOf: modelWindow("Design", response.sevenDayDesign))

            windows.append(UsageWindowInfo(
                id: "claude-weekly",
                kind: .weekly,
                label: "7-day total",
                usedFraction: sd.utilization,
                resetsAt: date,
                perModel: perModel.isEmpty ? nil : perModel
            ))
        }

        return windows
    }

    private static func modelWindow(_ name: String, _ window: UsageWindow?) -> [ModelUsage] {
        guard let w = window, let date = parseISO8601(w.resetsAt) else { return [] }
        return [ModelUsage(
            id: "claude-weekly-\(name.lowercased())",
            displayName: name,
            usedFraction: w.utilization,
            resetsAt: date
        )]
    }

    private static func extractPerModelUsage(from limits: [UsageLimit]?, kind: String) -> [ModelUsage] {
        guard let limits else { return [] }
        return limits.compactMap { limit -> ModelUsage? in
            guard limit.kind == kind,
                  let model = limit.scope?.model,
                  let date = parseISO8601(limit.resetsAt) else { return nil }
            return ModelUsage(
                id: "claude-\(kind)-\(model.id)",
                displayName: model.displayName,
                usedFraction: limit.percent,
                resetsAt: date
            )
        }
    }

    nonisolated(unsafe) private static let iso8601Formatter = ISO8601DateFormatter()
    private static func parseISO8601(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
    }
}

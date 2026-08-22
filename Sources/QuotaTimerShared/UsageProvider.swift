import Foundation

public enum UsageWindowKind: String, Sendable, Codable {
    case session
    case weekly
    case monthly
}

public struct UsageWindowInfo: Sendable, Identifiable, Equatable {
    public let id: String
    public let kind: UsageWindowKind
    public let label: String
    public let usedFraction: Double
    public let resetsAt: Date
    public let perModel: [ModelUsage]?

    public init(id: String, kind: UsageWindowKind, label: String, usedFraction: Double, resetsAt: Date, perModel: [ModelUsage]? = nil) {
        self.id = id
        self.kind = kind
        self.label = label
        self.usedFraction = usedFraction
        self.resetsAt = resetsAt
        self.perModel = perModel
    }
}

public struct ModelUsage: Sendable, Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let usedFraction: Double
    public let resetsAt: Date

    public init(id: String, displayName: String, usedFraction: Double, resetsAt: Date) {
        self.id = id
        self.displayName = displayName
        self.usedFraction = usedFraction
        self.resetsAt = resetsAt
    }
}

public protocol UsageProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func fetch() async throws -> [UsageWindowInfo]
}

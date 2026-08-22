import Foundation
import Observation

public enum CountdownState: Sendable {
    case running
    case fired
    case cancelled
}

public struct CountdownTimer: Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let fireAt: Date
    public let createdAt: Date
    public private(set) var state: CountdownState

    public init(id: UUID = UUID(), label: String, fireAt: Date, createdAt: Date = Date()) {
        self.id = id
        self.label = label
        self.fireAt = fireAt
        self.createdAt = createdAt
        self.state = .running
    }

    public init(id: UUID = UUID(), label: String, duration: TimeInterval, now: Date = Date()) {
        self.id = id
        self.label = label
        self.fireAt = now.addingTimeInterval(duration)
        self.createdAt = now
        self.state = .running
    }

    public func remaining(at now: Date = Date()) -> TimeInterval {
        max(0, fireAt.timeIntervalSince(now))
    }

    public var isExpired: Bool {
        state == .fired || state == .cancelled
    }

    mutating func markFired() { state = .fired }
    mutating func markCancelled() { state = .cancelled }
}

@Observable @MainActor
public final class TimerEngine {
    public private(set) var timers: [CountdownTimer] = []
    public var onFire: ((CountdownTimer) -> Void)?

    private var tickTask: Task<Void, Never>?

    public init() {}

    public func start() {
        guard tickTask == nil else { return }
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    public func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    public func addTimer(label: String, duration: TimeInterval) {
        let timer = CountdownTimer(label: label, duration: duration)
        timers.append(timer)
    }

    public func addTimer(label: String, fireAt: Date) {
        guard fireAt > Date() else { return }
        let timer = CountdownTimer(label: label, fireAt: fireAt)
        timers.append(timer)
    }

    public func cancelTimer(id: UUID) {
        guard let idx = timers.firstIndex(where: { $0.id == id }) else { return }
        timers[idx].markCancelled()
    }

    public func removeTimer(id: UUID) {
        timers.removeAll { $0.id == id }
    }

    public func clearFired() {
        timers.removeAll { $0.state == .fired }
    }

    public var activeTimers: [CountdownTimer] {
        timers.filter { $0.state == .running }
    }

    public var firedTimers: [CountdownTimer] {
        timers.filter { $0.state == .fired }
    }

    public func tick() {
        let now = Date()
        for i in timers.indices {
            if timers[i].state == .running && timers[i].remaining(at: now) <= 0 {
                timers[i].markFired()
                onFire?(timers[i])
            }
        }
    }
}

public struct TimerPreset: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let fireAt: Date

    public init(id: String, label: String, fireAt: Date) {
        self.id = id
        self.label = label
        self.fireAt = fireAt
    }
}

extension TimerEngine {
    public static func presets(from windows: [UsageWindowInfo]) -> [TimerPreset] {
        var presets: [TimerPreset] = []
        let now = Date()

        for window in windows {
            guard window.resetsAt > now else { continue }

            presets.append(TimerPreset(
                id: "\(window.id)-reset",
                label: "Alarm at \(window.label) reset",
                fireAt: window.resetsAt
            ))

            let fifteenBefore = window.resetsAt.addingTimeInterval(-900)
            if fifteenBefore > now {
                presets.append(TimerPreset(
                    id: "\(window.id)-15min",
                    label: "15 min before \(window.label) reset",
                    fireAt: fifteenBefore
                ))
            }
        }

        return presets
    }
}

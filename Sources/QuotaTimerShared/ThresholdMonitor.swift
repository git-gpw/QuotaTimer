import Foundation

@MainActor
public final class ThresholdMonitor {
    private let settings: AppSettings
    private let notifier: AlarmNotifier

    private var notified: [String: Set<Int>] = [:]
    private var lastResetDates: [String: Date] = [:]

    public init(settings: AppSettings, notifier: AlarmNotifier = .shared) {
        self.settings = settings
        self.notifier = notifier
    }

    public func check(windows: [UsageWindowInfo]) {
        for window in windows {
            if let lastReset = lastResetDates[window.id], lastReset != window.resetsAt {
                notified[window.id] = []
            }
            lastResetDates[window.id] = window.resetsAt

            let currentPercent = Int(window.usedFraction * 100)
            let alreadyNotified = notified[window.id] ?? []

            for threshold in settings.thresholds.sorted() {
                if currentPercent >= threshold && !alreadyNotified.contains(threshold) {
                    notifier.fireThreshold(window: window, percent: threshold)
                    notified[window.id, default: []].insert(threshold)
                }
            }
        }
    }

    public func notifiedThresholds(for windowId: String) -> Set<Int> {
        notified[windowId] ?? []
    }

    public func reset() {
        notified = [:]
        lastResetDates = [:]
    }
}

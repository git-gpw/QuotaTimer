import Foundation
import AppKit

public final class AlarmNotifier: Sendable {
    public static let shared = AlarmNotifier()

    private init() {}

    public func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        Task { @MainActor in
            NotificationHelper.shared.requestPermission()
        }
    }

    public func fire(timer: CountdownTimer) {
        NSSound.beep()
        guard Bundle.main.bundleIdentifier != nil else { return }
        Task { @MainActor in
            NotificationHelper.shared.postNotification(timer: timer)
        }
    }

    public func fireThreshold(window: UsageWindowInfo, percent: Int) {
        NSSound.beep()
        guard Bundle.main.bundleIdentifier != nil else { return }
        Task { @MainActor in
            NotificationHelper.shared.postThresholdNotification(window: window, percent: percent)
        }
    }
}

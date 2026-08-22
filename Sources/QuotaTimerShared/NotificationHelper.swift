import Foundation
import UserNotifications

@MainActor
final class NotificationHelper: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationHelper()

    private override init() {
        super.init()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        UNUserNotificationCenter.current().delegate = self
    }

    func postNotification(timer: CountdownTimer) {
        let content = UNMutableNotificationContent()
        content.title = "QuotaTimer"
        content.body = "\(timer.label) — timer complete"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: timer.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func postThresholdNotification(window: UsageWindowInfo, percent: Int) {
        let content = UNMutableNotificationContent()
        content.title = "QuotaTimer — \(percent)% used"
        content.body = "\(window.label) is at \(percent)% utilization"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "threshold-\(window.id)-\(percent)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

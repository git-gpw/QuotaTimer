import AppKit
import SwiftUI
import QuotaTimerShared

@MainActor
final class WidgetManager {
    private var timerPanel: FloatingPanel?
    private var usagePanel: FloatingPanel?

    private let pollers: [UsagePoller]
    private let timerEngine: TimerEngine
    private let settings: AppSettings

    init(pollers: [UsagePoller], timerEngine: TimerEngine, settings: AppSettings) {
        self.pollers = pollers
        self.timerEngine = timerEngine
        self.settings = settings
    }

    func syncWidgets() {
        if settings.showTimerWidget {
            showTimerWidget()
        } else {
            hideTimerWidget()
        }
        if settings.showUsageWidget {
            showUsageWidget()
        } else {
            hideUsageWidget()
        }
    }

    private func showTimerWidget() {
        guard timerPanel == nil else { return }
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 60),
            identifier: "QuotaTimer.TimerWidget"
        )
        let view = TimerWidgetView(engine: timerEngine)
            .applyAppearance(settings.appearance)
        panel.contentView = NSHostingView(rootView: view)
        if panel.frame.origin == .zero {
            panel.center()
        }
        panel.orderFront(nil)
        timerPanel = panel
    }

    private func hideTimerWidget() {
        timerPanel?.close()
        timerPanel = nil
    }

    private func showUsageWidget() {
        guard usagePanel == nil else { return }
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            identifier: "QuotaTimer.UsageWidget"
        )
        let view = UsageWidgetView(pollers: pollers, settings: settings)
            .applyAppearance(settings.appearance)
        panel.contentView = NSHostingView(rootView: view)
        if panel.frame.origin == .zero {
            panel.center()
        }
        panel.orderFront(nil)
        usagePanel = panel
    }

    private func hideUsageWidget() {
        usagePanel?.close()
        usagePanel = nil
    }
}

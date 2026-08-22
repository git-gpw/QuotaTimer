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
        Task { @MainActor [weak self] in
            self?.syncWidgets()
            self?.observeChanges()
        }
    }

    func syncWidgets() {
        DebugLog.shared.log("syncWidgets called: timer=\(settings.showTimerWidget), usage=\(settings.showUsageWidget)")
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

    private func observeChanges() {
        withObservationTracking {
            _ = settings.showTimerWidget
            _ = settings.showUsageWidget
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.syncWidgets()
                self?.observeChanges()
            }
        }
    }

    private func showTimerWidget() {
        guard timerPanel == nil else { return }
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 60),
            identifier: "QuotaTimer.TimerWidget"
        )
        let hostingView = NSHostingView(rootView: TimerWidgetView(engine: timerEngine))
        hostingView.frame = panel.contentView?.bounds ?? panel.contentLayoutRect
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        if panel.frame.origin == .zero {
            panel.center()
        }
        panel.orderFrontRegardless()
        timerPanel = panel
        DebugLog.shared.log("Timer widget panel shown at \(panel.frame)")
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
        let hostingView = NSHostingView(rootView: UsageWidgetView(pollers: pollers, settings: settings))
        hostingView.frame = panel.contentView?.bounds ?? panel.contentLayoutRect
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        if panel.frame.origin == .zero {
            panel.center()
        }
        panel.orderFrontRegardless()
        usagePanel = panel
        DebugLog.shared.log("Usage widget panel shown at \(panel.frame)")
    }

    private func hideUsageWidget() {
        usagePanel?.close()
        usagePanel = nil
    }
}

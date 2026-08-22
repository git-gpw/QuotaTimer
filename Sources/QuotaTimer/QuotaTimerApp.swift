import SwiftUI
import Sparkle
import QuotaTimerShared

@main
struct QuotaTimerApp: App {
    @State private var pollers: [UsagePoller] = [
        UsagePoller(provider: ClaudeUsageProvider()),
        UsagePoller(provider: CodexUsageProvider()),
    ]
    @State private var timerEngine = TimerEngine()
    @State private var settings = AppSettings()
    @State private var thresholdMonitor: ThresholdMonitor?
    @State private var widgetManager: WidgetManager?
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(
                pollers: pollers,
                timerEngine: timerEngine,
                settings: settings,
                updater: updaterController.updater
            )
            .onAppear {
                AlarmNotifier.shared.requestPermission()
                timerEngine.onFire = { timer in
                    AlarmNotifier.shared.fire(timer: timer)
                }
                if thresholdMonitor == nil {
                    thresholdMonitor = ThresholdMonitor(settings: settings)
                }
                if widgetManager == nil {
                    widgetManager = WidgetManager(
                        pollers: pollers,
                        timerEngine: timerEngine,
                        settings: settings
                    )
                }
                widgetManager?.syncWidgets()
            }
            .onChange(of: allWindows) { _, newWindows in
                thresholdMonitor?.check(windows: newWindows)
            }
            .onChange(of: settings.showTimerWidget) { _, _ in
                widgetManager?.syncWidgets()
            }
            .onChange(of: settings.showUsageWidget) { _, _ in
                widgetManager?.syncWidgets()
            }
        } label: {
            MenuBarLabel(pollers: pollers)
        }
        .menuBarExtraStyle(.window)
    }

    private var allWindows: [UsageWindowInfo] {
        pollers.flatMap(\.windows)
    }
}

import SwiftUI
import Sparkle
import QuotaTimerShared

@main
struct QuotaTimerApp: App {
    @State private var pollers: [UsagePoller]
    @State private var timerEngine: TimerEngine
    @State private var settings: AppSettings
    @State private var thresholdMonitor: ThresholdMonitor?
    @State private var widgetManager: WidgetManager
    private let updaterController: SPUStandardUpdaterController

    init() {
        let pollers = [
            UsagePoller(provider: ClaudeUsageProvider()),
            UsagePoller(provider: CodexUsageProvider()),
        ]
        let timerEngine = TimerEngine()
        let settings = AppSettings()

        _pollers = State(wrappedValue: pollers)
        _timerEngine = State(wrappedValue: timerEngine)
        _settings = State(wrappedValue: settings)
        _widgetManager = State(wrappedValue: WidgetManager(
            pollers: pollers,
            timerEngine: timerEngine,
            settings: settings
        ))

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
            }
            .onChange(of: allWindows) { _, newWindows in
                thresholdMonitor?.check(windows: newWindows)
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

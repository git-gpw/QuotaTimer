import SwiftUI
import QuotaTimerShared

struct SettingsView: View {
    let settings: AppSettings
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 4) {
                Text("Threshold alerts")
                    .font(.system(size: 12, weight: .medium))

                ForEach([50, 75, 90], id: \.self) { level in
                    Toggle("\(level)%", isOn: Binding(
                        get: { settings.isThresholdEnabled(level) },
                        set: { _ in settings.toggleThreshold(level) }
                    ))
                    .font(.system(size: 11))
                    .toggleStyle(.checkbox)
                }
            }

            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Floating widgets")
                    .font(.system(size: 12, weight: .medium))

                Toggle("Timer widget", isOn: Binding(
                    get: { settings.showTimerWidget },
                    set: { settings.showTimerWidget = $0 }
                ))
                .font(.system(size: 11))
                .toggleStyle(.checkbox)

                Toggle("Usage widget", isOn: Binding(
                    get: { settings.showUsageWidget },
                    set: { settings.showUsageWidget = $0 }
                ))
                .font(.system(size: 11))
                .toggleStyle(.checkbox)
            }

            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)

            Toggle("Pomodoro presets", isOn: Binding(
                get: { settings.pomodoroEnabled },
                set: { settings.pomodoroEnabled = $0 }
            ))
            .font(.system(size: 11))
            .toggleStyle(.checkbox)

            Toggle("Launch at login", isOn: Binding(
                get: { LaunchAtLogin.isEnabled },
                set: { newValue in
                    do {
                        try LaunchAtLogin.setEnabled(newValue)
                        settings.launchAtLogin = newValue
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                    }
                }
            ))
            .font(.system(size: 11))
            .toggleStyle(.checkbox)

            if let err = loginError {
                Text(err)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
    }
}

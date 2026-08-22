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

            VStack(alignment: .leading, spacing: 6) {
                Text("Appearance")
                    .font(.system(size: 12, weight: .medium))

                HStack(spacing: 8) {
                    AppearanceChoice(
                        label: "Light",
                        icon: "sun.max",
                        selected: settings.appearance == .light
                    ) {
                        settings.appearance = .light
                    }

                    AppearanceChoice(
                        label: "Dark",
                        icon: "moon",
                        selected: settings.appearance == .dark
                    ) {
                        settings.appearance = .dark
                    }

                    AppearanceChoice(
                        label: "System",
                        icon: "desktopcomputer",
                        selected: settings.appearance == .system
                    ) {
                        settings.appearance = .system
                    }
                }
            }

            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)

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

struct AppearanceChoice: View {
    let label: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 36, height: 28)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selected ? AnyShapeStyle(.blue.opacity(0.12)) : AnyShapeStyle(.quaternary))
                    }

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(selected ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.blue.opacity(0.3), lineWidth: 1.5)
                        .padding(-4)
                }
            }
        }
        .buttonStyle(.borderless)
    }
}

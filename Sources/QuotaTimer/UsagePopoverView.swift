import SwiftUI
import Sparkle
import QuotaTimerShared

struct UsagePopoverView: View {
    let pollers: [UsagePoller]
    let timerEngine: TimerEngine
    let settings: AppSettings
    let updater: SPUUpdater
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var enabledPollers: [UsagePoller] {
        pollers.filter { poller in
            let name = poller.providerName.lowercased()
            if name.contains("claude") { return settings.claudeEnabled }
            if name.contains("codex") { return settings.codexEnabled }
            return true
        }
    }

    private var allWindows: [UsageWindowInfo] {
        enabledPollers.flatMap(\.windows)
    }

    private var anyLoading: Bool {
        enabledPollers.contains {
            if case .loading = $0.state { return true }
            return false
        }
    }

    private var latestUpdate: Date? {
        pollers.compactMap(\.lastUpdated).max()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                divider

                let visible = enabledPollers
                ForEach(Array(visible.enumerated()), id: \.offset) { idx, poller in
                    PollerSectionView(poller: poller, now: now)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    if idx < visible.count - 1 {
                        divider
                    }
                }

                divider

                TimerSectionView(
                    engine: timerEngine,
                    presets: TimerEngine.presets(from: allWindows),
                    pomodoroEnabled: settings.pomodoroEnabled,
                    now: now
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                divider

                ConnectionsView(pollers: pollers, settings: settings)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                divider

                SettingsView(settings: settings)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                divider

                footer
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .frame(width: 300)
        .frame(maxHeight: 500)
        .applyAppearance(settings.appearance)
        .task {
            for poller in pollers { poller.start() }
        }
        .task { timerEngine.start() }
        .onReceive(timer) { now = $0 }
    }

    private var divider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center) {
            Text("QuotaTimer")
                .font(.system(size: 15, weight: .semibold))
            Text("v0.1.0")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            if anyLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if let updated = latestUpdate {
                Text("Updated \(updated, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Refresh") {
                Task {
                    for poller in pollers { await poller.pollOnce() }
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
        }
        HStack {
            CheckForUpdatesView(updater: updater)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }
}

struct PollerSectionView: View {
    let poller: UsagePoller
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(providerColor)
                    .frame(width: 8, height: 8)
                Text(poller.providerName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            switch poller.state {
            case .idle, .loading:
                Text("Loading usage...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

            case .loaded(let windows):
                if windows.isEmpty {
                    Text("No usage data available")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(windows) { window in
                            WindowRow(window: window, now: now)
                        }
                    }
                }

            case .tokenExpired:
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Token expired")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                        Text("Re-authenticate to refresh")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

            case .error(let kind):
                HStack(spacing: 6) {
                    Image(systemName: errorIcon(kind))
                        .foregroundStyle(errorColor(kind))
                        .font(.system(size: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.userMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(errorColor(kind))
                        HStack(spacing: 8) {
                            Text("Details in log file")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Button("View Log") {
                                NSWorkspace.shared.open(DebugLog.shared.logFileURL)
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 10))
                        }
                    }
                }
            }
        }
    }

    private var providerColor: Color {
        poller.providerName.lowercased().contains("claude") ? Color.orange : .green
    }

    private func errorIcon(_ kind: PollerErrorKind) -> String {
        switch kind {
        case .credentialNotFound: return "person.crop.circle.badge.questionmark"
        case .networkError: return "wifi.slash"
        case .rateLimited: return "clock.arrow.circlepath"
        case .decodingError, .httpError, .unknown: return "exclamationmark.circle.fill"
        case .tokenExpired: return "exclamationmark.triangle.fill"
        }
    }

    private func errorColor(_ kind: PollerErrorKind) -> Color {
        switch kind {
        case .credentialNotFound: return .secondary
        case .networkError: return .orange
        case .rateLimited: return .yellow
        case .tokenExpired: return .orange
        case .decodingError, .httpError, .unknown: return .red
        }
    }
}

struct WindowRow: View {
    let window: UsageWindowInfo
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatPct(window.usedFraction))
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(QTColors.forFraction(window.usedFraction))
                Text("resets \(shortTimeUntil(window.resetsAt, from: now))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            GradientProgressBar(fraction: window.usedFraction)

            if let models = window.perModel, !models.isEmpty {
                VStack(spacing: 2) {
                    ForEach(models) { model in
                        HStack {
                            Text(model.displayName)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text(formatPct(model.usedFraction))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(QTColors.forFraction(model.usedFraction))
                        }
                    }
                }
                .padding(.leading, 12)
            }
        }
    }

    private func formatPct(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private func shortTimeUntil(_ target: Date, from now: Date) -> String {
        let remaining = target.timeIntervalSince(now)
        if remaining <= 0 { return "now" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 24 {
            return "\(hours / 24)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

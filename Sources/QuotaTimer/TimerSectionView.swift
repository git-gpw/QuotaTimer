import SwiftUI
import QuotaTimerShared

struct TimerSectionView: View {
    let engine: TimerEngine
    let presets: [TimerPreset]
    let pomodoroEnabled: Bool
    let now: Date
    @State private var customMinutes: Double = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            timerCard

            if !presets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reset Alarms")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(presets) { preset in
                        Button {
                            engine.addTimer(label: preset.label, fireAt: preset.fireAt)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 10))
                                Text(preset.label)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatTimeUntil(preset.fireAt))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                    Text("Timer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.blue)
                        .textCase(.uppercase)
                }
                Spacer()
                if !engine.activeTimers.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Running")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if let active = engine.activeTimers.first {
                activeTimerDisplay(active)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)

                if engine.activeTimers.count > 1 {
                    ForEach(engine.activeTimers.dropFirst()) { t in
                        HStack {
                            Text(t.label)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatRemaining(t.remaining(at: now)))
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button {
                                engine.cancelTimer(id: t.id)
                                engine.removeTimer(id: t.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                    }
                    Spacer().frame(height: 8)
                }
            }

            if !engine.firedTimers.isEmpty {
                VStack(spacing: 4) {
                    ForEach(engine.firedTimers) { timer in
                        HStack(spacing: 6) {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 10))
                            Text(timer.label)
                                .font(.system(size: 11))
                                .strikethrough()
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Done")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Button("Clear finished") {
                        engine.clearFired()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            if engine.activeTimers.isEmpty && engine.firedTimers.isEmpty && !pomodoroEnabled {
                Text("No timers running")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }

            if pomodoroEnabled {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 1)

                pomodoroPresets
                    .padding(12)
            }

            if !pomodoroEnabled && (engine.activeTimers.isEmpty && engine.firedTimers.isEmpty) {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 1)

                customTimerRow
                    .padding(12)
            } else if !pomodoroEnabled {
                customTimerRow
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.blue.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.blue.opacity(0.12), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func activeTimerDisplay(_ timer: CountdownTimer) -> some View {
        VStack(spacing: 4) {
            Text(formatRemaining(timer.remaining(at: now)))
                .font(.system(size: 36, weight: .semibold).monospacedDigit())

            Text(timer.label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            let total = timer.fireAt.timeIntervalSince(timer.createdAt)
            let elapsed = now.timeIntervalSince(timer.createdAt)
            let progress = total > 0 ? min(elapsed / total, 1.0) : 0

            GradientProgressBar(
                fraction: progress,
                height: 4,
                pulseWhenHigh: false
            )
            .overlay {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * min(CGFloat(progress), 1.0))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 4)
            }
            .padding(.top, 6)

            Button("Cancel") {
                engine.cancelTimer(id: timer.id)
                engine.removeTimer(id: timer.id)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .foregroundStyle(.red)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var pomodoroPresets: some View {
        HStack(spacing: 6) {
            PomodoroButton(label: "Focus", minutes: 25, accent: true) {
                engine.addTimer(label: "Focus session", duration: 25 * 60)
            }
            PomodoroButton(label: "Break", minutes: 5, accent: false) {
                engine.addTimer(label: "Break", duration: 5 * 60)
            }
            PomodoroButton(label: "Long", minutes: 15, accent: false) {
                engine.addTimer(label: "Long break", duration: 15 * 60)
            }
            Button {
                engine.addTimer(
                    label: "\(Int(customMinutes))m timer",
                    duration: customMinutes * 60
                )
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Custom")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        )
                }
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var customTimerRow: some View {
        HStack(spacing: 8) {
            Text("Custom:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Picker("", selection: $customMinutes) {
                Text("1m").tag(1.0)
                Text("5m").tag(5.0)
                Text("10m").tag(10.0)
                Text("15m").tag(15.0)
                Text("25m").tag(25.0)
                Text("30m").tag(30.0)
                Text("45m").tag(45.0)
                Text("60m").tag(60.0)
            }
            .labelsHidden()
            .frame(width: 60)
            Button("Start") {
                engine.addTimer(
                    label: "\(Int(customMinutes))m timer",
                    duration: customMinutes * 60
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func formatRemaining(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func formatTimeUntil(_ date: Date) -> String {
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "now" }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct PomodoroButton: View {
    let label: String
    let minutes: Int
    let accent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text("\(minutes)")
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundStyle(accent ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(accent ? AnyShapeStyle(.blue.opacity(0.12)) : AnyShapeStyle(.quaternary))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(accent ? AnyShapeStyle(.blue.opacity(0.3)) : AnyShapeStyle(.quaternary), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.borderless)
    }
}

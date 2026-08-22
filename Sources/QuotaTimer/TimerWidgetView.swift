import SwiftUI
import QuotaTimerShared

struct TimerWidgetView: View {
    let engine: TimerEngine
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            if let active = engine.activeTimers.first {
                Image(systemName: "timer")
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 1) {
                    Text(formatRemaining(active.remaining(at: now)))
                        .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    Text(active.label)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "timer")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("No timer")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        }
        .onReceive(tick) { now = $0 }
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
}

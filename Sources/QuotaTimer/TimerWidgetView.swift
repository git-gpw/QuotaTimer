import SwiftUI
import QuotaTimerShared

struct TimerWidgetView: View {
    let engine: TimerEngine
    let settings: AppSettings
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let baseWidth: CGFloat = 180
    private static let baseHeight: CGFloat = 60

    var body: some View {
        GeometryReader { geo in
            let scale = min(
                geo.size.width / Self.baseWidth,
                geo.size.height / Self.baseHeight
            )
            content
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button("Hide Timer Widget") {
                settings.showTimerWidget = false
            }
        }
        .onReceive(tick) { now = $0 }
    }

    private var content: some View {
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

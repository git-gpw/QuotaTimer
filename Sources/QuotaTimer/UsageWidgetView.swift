import SwiftUI
import QuotaTimerShared

struct UsageWidgetView: View {
    let pollers: [UsagePoller]
    let settings: AppSettings

    private static let baseWidth: CGFloat = 200
    private static let baseHeight: CGFloat = 80

    private var enabledPollers: [UsagePoller] {
        pollers.filter { poller in
            let name = poller.providerName.lowercased()
            if name.contains("claude") { return settings.claudeEnabled }
            if name.contains("codex") { return settings.codexEnabled }
            return true
        }
    }

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
        .overlay(alignment: .bottomLeading) { GripIndicator() }
        .contextMenu {
            Button("Hide Usage Widget") {
                settings.showUsageWidget = false
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(enabledPollers.enumerated()), id: \.offset) { _, poller in
                if case .loaded(let windows) = poller.state {
                    ForEach(windows) { window in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(providerColor(poller))
                                .frame(width: 6, height: 6)
                            Text(window.label)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(formatPct(window.usedFraction))
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                .foregroundStyle(QTColors.forFraction(window.usedFraction))
                        }
                        GradientProgressBar(fraction: window.usedFraction, height: 4, pulseWhenHigh: true)
                    }
                }
            }

            if enabledPollers.allSatisfy({ $0.windows.isEmpty }) {
                Text("No usage data")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .frame(width: Self.baseWidth, height: Self.baseHeight)
    }

    private func providerColor(_ poller: UsagePoller) -> Color {
        poller.providerName.lowercased().contains("claude") ? .orange : .green
    }

    private func formatPct(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}

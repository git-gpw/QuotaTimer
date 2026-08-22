import SwiftUI
import QuotaTimerShared

enum QTColors {
    static func forFraction(_ f: Double) -> Color {
        switch f {
        case ..<0.5: return .green
        case ..<0.75: return .yellow
        case ..<0.9: return .orange
        default: return .red
        }
    }

    static func gradient(for fraction: Double) -> LinearGradient {
        let stops: [Gradient.Stop]
        let clamped = min(fraction, 1.0)

        if clamped < 0.5 {
            stops = [
                .init(color: .green, location: 0),
                .init(color: .green, location: 1),
            ]
        } else if clamped < 0.75 {
            stops = [
                .init(color: .green, location: 0),
                .init(color: .yellow, location: 1),
            ]
        } else if clamped < 0.9 {
            stops = [
                .init(color: .green, location: 0),
                .init(color: .yellow, location: 0.5),
                .init(color: .orange, location: 1),
            ]
        } else {
            stops = [
                .init(color: .green, location: 0),
                .init(color: .yellow, location: 0.35),
                .init(color: .orange, location: 0.65),
                .init(color: .red, location: 1),
            ]
        }

        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }
}

struct GradientProgressBar: View {
    let fraction: Double
    var height: CGFloat = 6
    var pulseWhenHigh = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(.quaternary)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(QTColors.gradient(for: fraction))
                    .frame(width: geo.size.width * min(CGFloat(fraction), 1.0))
                    .overlay {
                        if pulseWhenHigh && fraction >= 0.75 {
                            RoundedRectangle(cornerRadius: height / 2)
                                .fill(QTColors.forFraction(fraction).opacity(0.3))
                                .phaseAnimator([false, true]) { content, phase in
                                    content.opacity(phase ? 1.0 : 0.4)
                                } animation: { _ in
                                    .easeInOut(duration: fraction >= 0.9 ? 1.2 : 2.0)
                                }
                        }
                    }
            }
        }
        .frame(height: height)
    }
}
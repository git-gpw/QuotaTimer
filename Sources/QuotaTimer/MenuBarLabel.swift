import SwiftUI
import QuotaTimerShared

struct MenuBarLabel: View {
    let pollers: [UsagePoller]

    private var primaryPoller: UsagePoller? {
        pollers.first
    }

    private var maxFraction: Double? {
        pollers.flatMap(\.windows).map(\.usedFraction).max()
    }

    var body: some View {
        if let poller = primaryPoller {
            switch poller.state {
            case .idle, .loading:
                Label {
                    Text("--")
                } icon: {
                    Image(nsImage: Self.gaugeImage(fraction: 0))
                }
            case .loaded:
                if let fraction = maxFraction {
                    Label {
                        Text("\(Int(fraction * 100))%")
                    } icon: {
                        Image(nsImage: Self.gaugeImage(fraction: fraction))
                    }
                } else {
                    Label {
                        Text("--")
                    } icon: {
                        Image(nsImage: Self.gaugeImage(fraction: 0))
                    }
                }
            case .tokenExpired:
                Label("!", systemImage: "exclamationmark.triangle")
            case .error(let kind):
                switch kind {
                case .credentialNotFound:
                    Label("--", systemImage: "person.crop.circle.badge.questionmark")
                default:
                    Label("?", systemImage: "exclamationmark.circle")
                }
            }
        } else {
            Label {
                Text("--")
            } icon: {
                Image(nsImage: Self.gaugeImage(fraction: 0))
            }
        }
    }

    private static func gaugeImage(fraction: Double) -> NSImage {
        let size: CGFloat = 18
        let scale: CGFloat = 2
        let px = size * scale

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(px),
            pixelsHigh: Int(px),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: size, height: size)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ctx = NSGraphicsContext.current!.cgContext

        // Flip to screen coordinates (y-down, origin top-left)
        ctx.translateBy(x: 0, y: px)
        ctx.scaleBy(x: 1, y: -1)

        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)

        let color = CGColor(gray: 0, alpha: 1)
        let cx = px / 2
        let cy = px * 0.55
        let radius = px * 0.36
        let lineW = max(px * 0.085, 2)

        // In screen coords (y-down): 0°=right, angles increase clockwise
        // Gauge arc from 210° to 330°, sweeping counterclockwise through top (240°)
        // In flipped CGContext, clockwise:true = visually counterclockwise
        let startAngle = 210.0 * .pi / 180
        let endAngle = 330.0 * .pi / 180

        ctx.setStrokeColor(color)
        ctx.setLineWidth(lineW)
        ctx.setLineCap(.round)
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: radius,
                   startAngle: startAngle, endAngle: endAngle, clockwise: true)
        ctx.strokePath()

        // Needle: fraction 0→210° (left), fraction 1→330° (right)
        let clamped = min(max(fraction, 0), 1)
        let needleAngle = (210.0 - clamped * 240.0) * .pi / 180
        let needleLen = radius * 0.68
        let nx = cx + needleLen * cos(needleAngle)
        let ny = cy + needleLen * sin(needleAngle)

        ctx.setLineWidth(lineW * 1.2)
        ctx.move(to: CGPoint(x: cx, y: cy))
        ctx.addLine(to: CGPoint(x: nx, y: ny))
        ctx.strokePath()

        // Center pivot dot
        let dotR = px * 0.055
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: cx - dotR, y: cy - dotR,
                                    width: dotR * 2, height: dotR * 2))

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }
}

import AppKit

final class FloatingPanel: NSPanel {
    var snapSiblings: [FloatingPanel] = []
    private static let snapThreshold: CGFloat = 12

    init(contentRect: NSRect, identifier: String, minSize: NSSize? = nil, maxSize: NSSize? = nil) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        if let min = minSize { self.minSize = min }
        if let max = maxSize { self.maxSize = max }

        setFrameAutosaveName(identifier)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func setFrameOrigin(_ point: NSPoint) {
        var p = point
        let mySize = frame.size

        for sibling in snapSiblings where sibling.isVisible {
            let s = sibling.frame
            let t = Self.snapThreshold

            // Only snap when panels are in the same neighborhood —
            // vertically overlapping or adjacent (for horizontal snaps)
            // and horizontally overlapping or adjacent (for vertical snaps).
            let verticalProximity = p.y < s.maxY + t && (p.y + mySize.height) > s.minY - t
            let horizontalProximity = p.x < s.maxX + t && (p.x + mySize.width) > s.minX - t

            if verticalProximity {
                // Snap my left edge to sibling's right edge (stack right)
                if abs(p.x - s.maxX) < t { p.x = s.maxX }
                // Snap my right edge to sibling's left edge (stack left)
                else if abs((p.x + mySize.width) - s.minX) < t { p.x = s.minX - mySize.width }
                // Align left edges
                else if abs(p.x - s.minX) < t { p.x = s.minX }
                // Align right edges
                else if abs((p.x + mySize.width) - s.maxX) < t { p.x = s.maxX - mySize.width }
            }

            if horizontalProximity {
                // Snap my bottom edge to sibling's top edge (stack above)
                if abs(p.y - s.maxY) < t { p.y = s.maxY }
                // Snap my top edge to sibling's bottom edge (stack below)
                else if abs((p.y + mySize.height) - s.minY) < t { p.y = s.minY - mySize.height }
                // Align bottom edges
                else if abs(p.y - s.minY) < t { p.y = s.minY }
                // Align top edges
                else if abs((p.y + mySize.height) - s.maxY) < t { p.y = s.maxY - mySize.height }
            }
        }

        super.setFrameOrigin(p)
    }
}

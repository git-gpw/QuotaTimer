import AppKit

final class FloatingPanel: NSPanel {
    private var weakSiblings: NSHashTable<FloatingPanel> = .weakObjects()
    private var isPerformingGroupMove = false

    private static let snapThreshold: CGFloat = 12
    static let gripSize: CGFloat = 24

    var snapSiblings: [FloatingPanel] {
        get { weakSiblings.allObjects }
        set {
            weakSiblings.removeAllObjects()
            for s in newValue { weakSiblings.add(s) }
        }
    }

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

    // MARK: - Grip-zone solo drag

    var gripRect: NSRect {
        NSRect(x: 0, y: 0, width: Self.gripSize, height: Self.gripSize)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown && gripRect.contains(event.locationInWindow) {
            performSoloDrag()
            return
        }
        super.sendEvent(event)
    }

    private func performSoloDrag() {
        let initialMouse = NSEvent.mouseLocation
        let initialOrigin = frame.origin

        while true {
            guard let next = nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if next.type == .leftMouseUp { break }

            let mouse = NSEvent.mouseLocation
            let raw = NSPoint(
                x: initialOrigin.x + (mouse.x - initialMouse.x),
                y: initialOrigin.y + (mouse.y - initialMouse.y)
            )
            super.setFrameOrigin(snapPoint(raw))
        }
    }

    // MARK: - Group move (called by isMovableByWindowBackground drag)

    override func setFrameOrigin(_ point: NSPoint) {
        if isPerformingGroupMove {
            super.setFrameOrigin(point)
            return
        }

        let siblings = snapSiblings
        let snapped = siblings.filter { $0.isVisible && isSnappedTo($0) }

        if !snapped.isEmpty {
            let delta = NSPoint(x: point.x - frame.origin.x, y: point.y - frame.origin.y)
            super.setFrameOrigin(point)
            for sibling in snapped {
                sibling.isPerformingGroupMove = true
                let so = sibling.frame.origin
                sibling.setFrameOrigin(NSPoint(x: so.x + delta.x, y: so.y + delta.y))
                sibling.isPerformingGroupMove = false
            }
        } else {
            super.setFrameOrigin(snapPoint(point))
        }
    }

    // MARK: - Snap helpers

    func isSnappedTo(_ sibling: FloatingPanel) -> Bool {
        let a = frame, b = sibling.frame
        let e: CGFloat = 1

        let hTouch = abs(a.minX - b.maxX) < e || abs(a.maxX - b.minX) < e
        let vTouch = abs(a.minY - b.maxY) < e || abs(a.maxY - b.minY) < e
        let vOverlap = a.minY < b.maxY + e && a.maxY > b.minY - e
        let hOverlap = a.minX < b.maxX + e && a.maxX > b.minX - e

        return (hTouch && vOverlap) || (vTouch && hOverlap)
    }

    private func snapPoint(_ point: NSPoint) -> NSPoint {
        var p = point
        let mySize = frame.size

        for sibling in snapSiblings where sibling.isVisible {
            let s = sibling.frame
            let t = Self.snapThreshold

            let vProx = p.y < s.maxY + t && (p.y + mySize.height) > s.minY - t
            let hProx = p.x < s.maxX + t && (p.x + mySize.width) > s.minX - t

            if vProx {
                if abs(p.x - s.maxX) < t { p.x = s.maxX }
                else if abs((p.x + mySize.width) - s.minX) < t { p.x = s.minX - mySize.width }
                else if abs(p.x - s.minX) < t { p.x = s.minX }
                else if abs((p.x + mySize.width) - s.maxX) < t { p.x = s.maxX - mySize.width }
            }

            // Recompute horizontal proximity after possible x-snap
            let hProxUpdated = p.x < s.maxX + t && (p.x + mySize.width) > s.minX - t

            if hProxUpdated {
                if abs(p.y - s.maxY) < t { p.y = s.maxY }
                else if abs((p.y + mySize.height) - s.minY) < t { p.y = s.minY - mySize.height }
                else if abs(p.y - s.minY) < t { p.y = s.minY }
                else if abs((p.y + mySize.height) - s.maxY) < t { p.y = s.maxY - mySize.height }
            }
        }

        return p
    }
}

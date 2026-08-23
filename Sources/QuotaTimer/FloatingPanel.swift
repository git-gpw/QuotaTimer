import AppKit

final class FloatingPanel: NSPanel {
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
}

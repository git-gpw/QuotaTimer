import AppKit

final class FloatingPanel: NSPanel {
    init(contentRect: NSRect, identifier: String) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        setFrameAutosaveName(identifier)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

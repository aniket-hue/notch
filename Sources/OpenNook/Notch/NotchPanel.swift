import AppKit

/// A borderless, non-activating panel that floats above everything (including the
/// menu bar) and never steals focus from the app you're working in.
final class NotchPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar                       // above the menu bar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false                        // the SwiftUI shape draws its own shadow
        isMovable = false
        hidesOnDeactivate = false
        // Click-through by default. HoverMonitor flips this to `false` only while
        // the cursor is in the notch zone, so this fixed-size window never blocks
        // the apps beneath it.
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true

        // Show on every Space, stay put, and don't disrupt full-screen apps.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    // A borderless panel can't normally become key/main; we never want it to,
    // so that the app underneath keeps keyboard focus.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

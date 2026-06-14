import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: Settings
    private let registry: WidgetRegistry
    private let clipboard: ClipboardService

    init(settings: Settings, registry: WidgetRegistry, clipboard: ClipboardService) {
        self.settings = settings
        self.registry = registry
        self.clipboard = clipboard
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(settings: settings, registry: registry, clipboard: clipboard),
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "OpenNook Settings"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

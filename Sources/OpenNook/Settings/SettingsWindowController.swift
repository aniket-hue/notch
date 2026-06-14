import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let settings: Settings
    private let registry: WidgetRegistry
    private let clipboard: ClipboardService
    private let github: GitHubService

    init(settings: Settings, registry: WidgetRegistry, clipboard: ClipboardService, github: GitHubService) {
        self.settings = settings
        self.registry = registry
        self.clipboard = clipboard
        self.github = github
        super.init()
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(settings: settings, registry: registry, clipboard: clipboard, github: github),
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "OpenNook Settings"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

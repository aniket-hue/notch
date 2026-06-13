import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem?
    private var notchController: NotchWindowController?
    private var launchItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        notchController = NotchWindowController()
        notchController?.show()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                   accessibilityDescription: "OpenNook")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "OpenNook", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let launch = NSMenuItem(title: "Open at Login",
                                action: #selector(toggleLaunchAtLogin(_:)),
                                keyEquivalent: "")
        launch.target = self
        menu.addItem(launch)
        self.launchItem = launch

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit OpenNook",
                              action: #selector(quit),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        self.statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        launchItem?.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.toggle()
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

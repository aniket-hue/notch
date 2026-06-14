import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var notchController: NotchWindowController?

    func applicationDidFinishLaunching(_: Notification) {
        setupStatusItem()
        notchController = NotchWindowController()
        notchController?.show()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = Icon.menuBarImage()
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "OpenNook", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit OpenNook",
                              action: #selector(quit),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func openSettings() {
        notchController?.openSettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

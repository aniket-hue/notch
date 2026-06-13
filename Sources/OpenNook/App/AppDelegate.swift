import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var notchController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        notchController = NotchWindowController()
        notchController?.show()
    }

    // MARK: - Menu bar item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            // SF Symbol that looks like a little notch / inset.
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                   accessibilityDescription: "OpenNook")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "OpenNook", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit OpenNook",
                     action: #selector(quit),
                     keyEquivalent: "q")
        item.menu = menu
        self.statusItem = item
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

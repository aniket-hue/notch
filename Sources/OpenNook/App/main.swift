import AppKit

// Entry point. We run as an "accessory" (agent) app: no Dock icon, no main menu,
// just a menu-bar item and our floating notch panel.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

import AppKit

struct NotchGeometry {

    let closedWidth: CGFloat

    let closedHeight: CGFloat

    let hasHardwareNotch: Bool

    let screen: NSScreen

    var openSize: CGSize { CGSize(width: 544, height: 184) }
}

enum ScreenGeometry {

    static func current() -> NotchGeometry {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first!

        let topInset = screen.safeAreaInsets.top

        if topInset > 0 {

            let fullWidth = screen.frame.width
            let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
            let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
            var notchWidth = fullWidth - leftWidth - rightWidth

            if notchWidth <= 0 || notchWidth > fullWidth * 0.5 {
                notchWidth = 200
            }

            return NotchGeometry(closedWidth: notchWidth,
                                 closedHeight: topInset,
                                 hasHardwareNotch: true,
                                 screen: screen)
        } else {

            return NotchGeometry(closedWidth: 320,
                                 closedHeight: 32,
                                 hasHardwareNotch: false,
                                 screen: screen)
        }
    }
}

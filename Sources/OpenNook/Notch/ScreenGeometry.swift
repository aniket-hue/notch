import AppKit

struct NotchGeometry {
    let closedWidth: CGFloat
    let closedHeight: CGFloat
    let hasHardwareNotch: Bool
    let screen: NSScreen
    let openSize: CGSize
}

enum ScreenGeometry {
    static func current(rowSize: CGSize) -> NotchGeometry {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first!

        let topInset = screen.safeAreaInsets.top

        let closedWidth: CGFloat
        let closedHeight: CGFloat
        let hasNotch: Bool

        if topInset > 0 {
            let fullWidth = screen.frame.width
            let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
            let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
            var notchWidth = fullWidth - leftWidth - rightWidth
            if notchWidth <= 0 || notchWidth > fullWidth * 0.5 {
                notchWidth = 200
            }
            closedWidth = notchWidth
            closedHeight = topInset
            hasNotch = true
        } else {
            closedWidth = 320
            closedHeight = 32
            hasNotch = false
        }

        let openSize = CGSize(
            width: rowSize.width + LayoutMetrics.hPadding * 2,
            height: closedHeight + rowSize.height + LayoutMetrics.bottomPadding + LayoutMetrics.topGap,
        )

        return NotchGeometry(
            closedWidth: closedWidth,
            closedHeight: closedHeight,
            hasHardwareNotch: hasNotch,
            screen: screen,
            openSize: openSize,
        )
    }
}

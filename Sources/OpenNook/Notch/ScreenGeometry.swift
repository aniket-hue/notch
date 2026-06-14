import AppKit

struct NotchMetrics {
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let hasHardwareNotch: Bool
    let screen: NSScreen
}

enum ScreenGeometry {
    static func current() -> NotchMetrics {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first!

        let topInset = screen.safeAreaInsets.top

        if topInset > 0 {
            let left = screen.auxiliaryTopLeftArea?.width ?? 0
            let right = screen.auxiliaryTopRightArea?.width ?? 0
            var width = screen.frame.width - left - right
            if width <= 0 || width > screen.frame.width * 0.5 { width = 200 }
            return NotchMetrics(notchWidth: width, notchHeight: topInset, hasHardwareNotch: true, screen: screen)
        } else {
            let menubar = screen.frame.maxY - screen.visibleFrame.maxY
            return NotchMetrics(notchWidth: 220, notchHeight: max(menubar, 24), hasHardwareNotch: false, screen: screen)
        }
    }
}

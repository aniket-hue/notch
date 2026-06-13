import AppKit

/// Describes the physical notch (or its simulated stand-in) on a given screen.
struct NotchGeometry {
    /// Width of the closed notch shape, in points.
    let closedWidth: CGFloat
    /// Height of the closed notch shape, in points.
    let closedHeight: CGFloat
    /// Whether the display actually has a hardware notch.
    let hasHardwareNotch: Bool
    /// The screen this geometry was computed for.
    let screen: NSScreen

    /// Size of the panel when expanded ("open").
    var openSize: CGSize { CGSize(width: 450, height: 432) }
}

enum ScreenGeometry {

    /// Compute the notch geometry for the screen that has the menu bar (the "main" screen).
    static func current() -> NotchGeometry {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first!

        let topInset = screen.safeAreaInsets.top

        if topInset > 0 {
            // Real notch. Derive its width from the auxiliary top areas:
            // the notch sits between the left and right auxiliary regions.
            let fullWidth = screen.frame.width
            let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
            let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
            var notchWidth = fullWidth - leftWidth - rightWidth
            // Fallback / sanity clamp if the auxiliary areas aren't reported.
            if notchWidth <= 0 || notchWidth > fullWidth * 0.5 {
                notchWidth = 200
            }
            // Match the physical notch exactly. Because the notch cutout is a
            // non-display region, a black shape this size is invisible when
            // collapsed — the panel only becomes visible as it expands on hover.
            return NotchGeometry(closedWidth: notchWidth,
                                 closedHeight: topInset,
                                 hasHardwareNotch: true,
                                 screen: screen)
        } else {
            // No notch: a pill at the top-center stands in for it.
            return NotchGeometry(closedWidth: 320,
                                 closedHeight: 32,
                                 hasHardwareNotch: false,
                                 screen: screen)
        }
    }
}

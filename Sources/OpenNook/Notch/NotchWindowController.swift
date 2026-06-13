import AppKit
import SwiftUI

/// Owns the floating notch panel. Following the established approach (DynamicNotchKit,
/// boring.notch): the panel is a single **fixed-size** transparent window pinned to the
/// top-center. It is *never resized* — the notch shape grows/shrinks purely in SwiftUI
/// inside it, which keeps the motion smooth and free of window-resize artifacts.
/// Click-through is handled by HoverMonitor toggling `ignoresMouseEvents`.
@MainActor
final class NotchWindowController {

    private var panel: NotchPanel!
    private let viewModel: NotchViewModel
    private var container: NotchContainerView!
    private var hoverMonitor: HoverMonitor!
    private let stats = SystemStatsService()

    /// Transparent breathing room around the open panel (for its shadow). The window
    /// is fixed at openSize + these margins and never changes size.
    private let hMargin: CGFloat = 44
    private let bMargin: CGFloat = 52

    init() {
        let geometry = ScreenGeometry.current()
        self.viewModel = NotchViewModel(geometry: geometry)
        stats.start()
        buildPanel()
        hoverMonitor = HoverMonitor(viewModel: viewModel, panel: panel)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func show() {
        panel.orderFrontRegardless()
    }

    // MARK: - Building

    private func buildPanel() {
        let frame = fixedFrame()

        let panel = NotchPanel(contentRect: frame)
        let container = NotchContainerView(viewModel: viewModel)
        container.frame = NSRect(origin: .zero, size: frame.size)
        container.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: NotchView(viewModel: viewModel, stats: stats))
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        if #available(macOS 13.0, *) {
            hosting.sceneBridgingOptions = []
        }
        container.addSubview(hosting)

        panel.contentView = container
        self.panel = panel
        self.container = container
    }

    /// Fixed window: large enough to hold the open panel plus its shadow margin,
    /// pinned so its top edge sits at the very top of the screen, centered on the notch.
    private func fixedFrame() -> NSRect {
        let screen = viewModel.geometry.screen
        let w = viewModel.geometry.openSize.width + hMargin * 2
        let h = viewModel.geometry.openSize.height + bMargin
        let x = screen.frame.midX - w / 2
        let y = screen.frame.maxY - h
        return NSRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Screen changes

    @objc private func screenParametersChanged() {
        viewModel.geometry = ScreenGeometry.current()
        panel.setFrame(fixedFrame(), display: true)
    }
}

/// Routes mouse events only to the visible notch shape; transparent areas of the
/// (interactive) window don't grab clicks meant for content underneath.
final class NotchContainerView: NSView {
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let size = MainActor.assumeIsolated { viewModel.currentShapeSize }
        // Shape is centered horizontally and pinned to the top of the view.
        let rect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: bounds.height - size.height,
            width: size.width,
            height: size.height
        )
        guard rect.contains(point) else { return nil }
        return super.hitTest(point)
    }
}

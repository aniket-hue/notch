import AppKit

/// Drives the notch's open/closed state from the *absolute* cursor position with
/// hysteresis: a small zone around the notch opens it; a larger zone around the
/// expanded panel keeps it open. The zones come from fixed screen geometry — not
/// the window's current hit area — so resizing the window can't feed back into
/// hover detection. That eliminates the edge jitter / "sliding" you get with
/// `onHover` on a window that changes size.
@MainActor
final class HoverMonitor {

    private let viewModel: NotchViewModel
    private weak var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(viewModel: NotchViewModel, panel: NSPanel) {
        self.viewModel = viewModel
        self.panel = panel
        start()
    }

    private func start() {
        // Cursor over other apps / desktop.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.evaluate() }
        }
        // Cursor over our own (open, interactive) panel.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            if let self { MainActor.assumeIsolated { self.evaluate() } }
            return event
        }
        evaluate()
    }

    /// The screen-space region (bottom-left origin) that counts as "hovering".
    private func activeZone() -> CGRect {
        let geo = viewModel.geometry
        let f = geo.screen.frame

        if viewModel.isOpen {
            // Generous zone around the expanded panel so small wobbles don't close it.
            let w = geo.openSize.width, h = geo.openSize.height
            let m: CGFloat = 26
            return CGRect(x: f.midX - w / 2 - m, y: f.maxY - h - m, width: w + 2 * m, height: h + m)
        } else {
            // Tight zone hugging the notch so it's easy to trigger but not eager.
            let w = geo.closedWidth, h = geo.closedHeight
            let mx: CGFloat = 18, my: CGFloat = 16
            return CGRect(x: f.midX - w / 2 - mx, y: f.maxY - h - my, width: w + 2 * mx, height: h + my)
        }
    }

    private func evaluate() {
        let inside = activeZone().contains(NSEvent.mouseLocation)
        // The fixed window stays click-through except while the cursor is in the
        // notch/panel zone, so it never blocks the apps beneath it.
        panel?.ignoresMouseEvents = !inside
        if inside {
            viewModel.open()
        } else {
            viewModel.scheduleClose()
        }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}

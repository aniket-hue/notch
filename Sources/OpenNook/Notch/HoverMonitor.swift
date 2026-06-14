import AppKit

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
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.evaluate() }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            if let self { MainActor.assumeIsolated { self.evaluate() } }
            return event
        }
        evaluate()
    }

    private func activeZone() -> CGRect {
        let metrics = viewModel.metrics
        let f = metrics.screen.frame

        if viewModel.isOpen {
            let s = viewModel.openContentSize == .zero ? viewModel.closedSize : viewModel.openContentSize
            let m: CGFloat = 26
            return CGRect(x: f.midX - s.width / 2 - m, y: f.maxY - s.height - m, width: s.width + 2 * m, height: s.height + m)
        } else {
            let w = metrics.notchWidth, h = metrics.notchHeight
            let mx: CGFloat = 18, my: CGFloat = 16
            return CGRect(x: f.midX - w / 2 - mx, y: f.maxY - h - my, width: w + 2 * mx, height: h + my)
        }
    }

    private func evaluate() {
        let inside = activeZone().contains(NSEvent.mouseLocation)

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

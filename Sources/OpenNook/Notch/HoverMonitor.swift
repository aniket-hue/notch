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
        let geo = viewModel.geometry
        let f = geo.screen.frame

        if viewModel.isOpen {
            let w = geo.openSize.width, h = geo.openSize.height
            let m: CGFloat = 26
            return CGRect(x: f.midX - w / 2 - m, y: f.maxY - h - m, width: w + 2 * m, height: h + m)
        } else {
            let w = geo.closedWidth, h = geo.closedHeight
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

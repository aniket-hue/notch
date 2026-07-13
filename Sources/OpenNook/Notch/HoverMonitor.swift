import AppKit

@MainActor
final class HoverMonitor {
    private let viewModel: NotchViewModel
    private weak var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var wasInside: Bool?

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
        let f = viewModel.metrics.screen.frame
        let size: CGSize
        let mx: CGFloat
        let my: CGFloat
        switch viewModel.state {
        case .open:
            size = viewModel.openContentSize == .zero ? viewModel.closedSize : viewModel.openContentSize
            mx = 26; my = 26
        case .compact:
            size = viewModel.compactSize
            mx = 18; my = 14
        case .closed:
            size = viewModel.closedSize
            mx = 18; my = 16
        }
        return CGRect(x: f.midX - size.width / 2 - mx, y: f.maxY - size.height - my, width: size.width + 2 * mx, height: size.height + my)
    }

    private func evaluate() {
        let inside = activeZone().contains(NSEvent.mouseLocation)
        guard wasInside != inside else { return }
        wasInside = inside

        panel?.ignoresMouseEvents = !inside
        if inside {
            viewModel.open()
        } else {
            viewModel.collapse()
        }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}

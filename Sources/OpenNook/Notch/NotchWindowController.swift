import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {

    private var panel: NotchPanel!
    private let viewModel: NotchViewModel
    private var container: NotchContainerView!
    private var hoverMonitor: HoverMonitor!
    private let stats = SystemStatsService()
    private let nowPlaying = NowPlayingService()

    private let hMargin: CGFloat = 44
    private let bMargin: CGFloat = 52

    init() {
        let geometry = ScreenGeometry.current()
        self.viewModel = NotchViewModel(geometry: geometry)
        stats.start()
        nowPlaying.start()
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

    private func buildPanel() {
        let frame = fixedFrame()

        let panel = NotchPanel(contentRect: frame)
        let container = NotchContainerView(viewModel: viewModel)
        container.frame = NSRect(origin: .zero, size: frame.size)
        container.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: NotchView(viewModel: viewModel, stats: stats, nowPlaying: nowPlaying))
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

    private func fixedFrame() -> NSRect {
        let screen = viewModel.geometry.screen
        let w = viewModel.geometry.openSize.width + hMargin * 2
        let h = viewModel.geometry.openSize.height + bMargin
        let x = screen.frame.midX - w / 2
        let y = screen.frame.maxY - h
        return NSRect(x: x, y: y, width: w, height: h)
    }

    @objc private func screenParametersChanged() {
        viewModel.geometry = ScreenGeometry.current()
        panel.setFrame(fixedFrame(), display: true)
    }
}

final class NotchContainerView: NSView {
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let size = MainActor.assumeIsolated { viewModel.currentShapeSize }

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

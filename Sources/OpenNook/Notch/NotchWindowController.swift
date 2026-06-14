import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchWindowController {
    private var panel: NotchPanel!
    private let viewModel: NotchViewModel
    private var container: NotchContainerView!
    private var hoverMonitor: HoverMonitor!
    private let stats = SystemStatsService()
    private let nowPlaying = NowPlayingService()
    private let clipboard = ClipboardService()
    private let calendar = CalendarService()
    private let registry: WidgetRegistry
    private let settings = Settings()
    private lazy var settingsWindow = SettingsWindowController(settings: settings, registry: registry, clipboard: clipboard)
    private var cancellables: Set<AnyCancellable> = []

    private var pages: [LayoutConfig] {
        LayoutConfig.visible(hidden: settings.hiddenWidgets)
    }

    private let hMargin: CGFloat = 44
    private let bMargin: CGFloat = 52

    init() {
        registry = WidgetRegistry(stats: stats, nowPlaying: nowPlaying, clipboard: clipboard, calendar: calendar)
        let initialPages = LayoutConfig.visible(hidden: settings.hiddenWidgets)
        let geometry = ScreenGeometry.current(rowSize: NotchWindowController.contentSize(registry, initialPages))
        viewModel = NotchViewModel(geometry: geometry)
        clipboard.setLimit(settings.clipboardLimit)
        stats.start()
        nowPlaying.start()
        clipboard.start()
        calendar.start()
        buildPanel()
        hoverMonitor = HoverMonitor(viewModel: viewModel, panel: panel)
        observeSettings()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil,
        )
    }

    private func observeSettings() {
        settings.$hiddenWidgets
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.relayout() }
            }
            .store(in: &cancellables)

        settings.$clipboardLimit
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                MainActor.assumeIsolated { self?.clipboard.setLimit(value) }
            }
            .store(in: &cancellables)
    }

    private func relayout() {
        viewModel.geometry = ScreenGeometry.current(rowSize: NotchWindowController.contentSize(registry, pages))
        panel.setFrame(fixedFrame(), display: true)
    }

    private static func contentSize(_ registry: WidgetRegistry, _ pages: [LayoutConfig]) -> CGSize {
        let s = LayoutMetrics.pageSize(registry, pages)
        return CGSize(width: s.width, height: s.height + LayoutMetrics.dotsHeight)
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func openSettings() {
        settingsWindow.show()
    }

    private func buildPanel() {
        let frame = fixedFrame()

        let panel = NotchPanel(contentRect: frame)
        let container = NotchContainerView(viewModel: viewModel)
        container.frame = NSRect(origin: .zero, size: frame.size)
        container.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: NotchView(
            viewModel: viewModel,
            settings: settings,
            registry: registry,
            onOpenSettings: { [weak self] in self?.openSettings() },
        ))
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
        viewModel.geometry = ScreenGeometry.current(rowSize: NotchWindowController.contentSize(registry, pages))
        panel.setFrame(fixedFrame(), display: true)
    }
}

final class NotchContainerView: NSView {
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let size = MainActor.assumeIsolated { viewModel.currentShapeSize }
        let rect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: bounds.height - size.height,
            width: size.width,
            height: size.height,
        )
        guard rect.contains(point) else { return nil }
        return super.hitTest(point)
    }
}

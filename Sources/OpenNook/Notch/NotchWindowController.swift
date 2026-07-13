import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchWindowController {
    private var panel: NotchPanel!
    private let viewModel: NotchViewModel
    private var container: NotchContainerView!
    private var hoverMonitor: HoverMonitor!
    private var shelfDrop: ShelfDropController!
    private let stats = SystemStatsService()
    private let nowPlaying = NowPlayingService()
    private let clipboard = ClipboardService()
    private let calendar = CalendarService()
    private let github = GitHubService()
    private let usage = UsageService()
    private let shelf = ShelfService()
    private let mic = MicService()
    private let registry: WidgetRegistry
    private let settings = Settings()
    private lazy var settingsWindow = SettingsWindowController(settings: settings, registry: registry, clipboard: clipboard, github: github)
    private var cancellables: Set<AnyCancellable> = []

    init() {
        registry = WidgetRegistry(stats: stats, nowPlaying: nowPlaying, clipboard: clipboard, calendar: calendar, github: github, usage: usage)
        viewModel = NotchViewModel(metrics: ScreenGeometry.current())
        clipboard.setLimit(settings.clipboardLimit)
        stats.start()
        nowPlaying.start()
        clipboard.start()
        calendar.start()
        github.start()
        usage.start()
        buildPanel()
        hoverMonitor = HoverMonitor(viewModel: viewModel, panel: panel)
        shelfDrop = ShelfDropController(viewModel: viewModel, shelf: shelf)
        observeSettings()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil,
        )
    }

    private func observeSettings() {
        settings.$clipboardLimit
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                MainActor.assumeIsolated { self?.clipboard.setLimit(value) }
            }
            .store(in: &cancellables)

        nowPlaying.$now
            .map(\.artworkID)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.updateArtGradient() }
            }
            .store(in: &cancellables)

        nowPlaying.$now
            .map(\.hasTrack)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] active in
                MainActor.assumeIsolated { self?.viewModel.setActivity(active) }
            }
            .store(in: &cancellables)
    }

    private func updateArtGradient() {
        let now = nowPlaying.now
        viewModel.artGradient = now.hasTrack ? now.gradient : []
    }

    private func windowFrame(for metrics: NotchMetrics) -> NSRect {
        let frame = metrics.screen.frame
        let height = min(620, frame.height * 0.6)
        return NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height)
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func openSettings() {
        settingsWindow.show()
    }

    private func buildPanel() {
        let frame = windowFrame(for: viewModel.metrics)

        let panel = NotchPanel(contentRect: frame)
        let container = NotchContainerView(viewModel: viewModel)
        container.frame = NSRect(origin: .zero, size: frame.size)
        container.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: NotchView(
            viewModel: viewModel,
            settings: settings,
            shelf: shelf,
            nowPlaying: nowPlaying,
            mic: mic,
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

    @objc private func screenParametersChanged() {
        viewModel.metrics = ScreenGeometry.current()
        panel.setFrame(windowFrame(for: viewModel.metrics), display: true)
        shelfDrop.updateMetrics()
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
        let size = MainActor.assumeIsolated { () -> CGSize in
            switch viewModel.state {
            case .open:
                return viewModel.openContentSize == .zero ? viewModel.closedSize : viewModel.openContentSize
            case .compact:
                return viewModel.compactSize
            case .closed:
                return viewModel.closedSize
            }
        }
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

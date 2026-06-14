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
    private let github = GitHubService()
    private let usage = UsageService()
    private let shelf = ShelfService()
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
    }

    private func updateArtGradient() {
        let now = nowPlaying.now
        if now.hasTrack, let art = now.artwork {
            viewModel.artGradient = ColorExtractor.gradientColors(from: art)
        } else {
            viewModel.artGradient = []
        }
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
        let container = NotchContainerView(viewModel: viewModel, shelf: shelf)
        container.frame = NSRect(origin: .zero, size: frame.size)
        container.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: NotchView(
            viewModel: viewModel,
            settings: settings,
            shelf: shelf,
            registry: registry,
            stats: stats,
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
    }
}

final class NotchContainerView: NSView {
    private let viewModel: NotchViewModel
    private let shelf: ShelfService
    private var isDragging = false

    init(viewModel: NotchViewModel, shelf: ShelfService) {
        self.viewModel = viewModel
        self.shelf = shelf
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func contentSize() -> CGSize {
        MainActor.assumeIsolated {
            if viewModel.isOpen {
                return viewModel.openContentSize == .zero ? viewModel.closedSize : viewModel.openContentSize
            }
            return viewModel.closedSize
        }
    }

    private func contentRect() -> NSRect {
        let size = contentSize()
        return NSRect(
            x: (bounds.width - size.width) / 2,
            y: bounds.height - size.height,
            width: size.width,
            height: size.height,
        )
    }

    private func triggerRect() -> NSRect {
        let isOpen = MainActor.assumeIsolated { viewModel.isOpen }
        if isOpen { return contentRect() }
        let size = contentSize()
        let w = size.width + 60
        let h = size.height + 16
        return NSRect(x: (bounds.width - w) / 2, y: bounds.height - h, width: w, height: h)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isDragging {
            return triggerRect().contains(point) ? self : nil
        }
        let isOpen = MainActor.assumeIsolated { viewModel.isOpen }
        if isOpen {
            guard contentRect().contains(point) else { return nil }
            return super.hitTest(point)
        }
        return triggerRect().contains(point) ? self : nil
    }

    private func hasFiles(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if hasFiles(sender) { isDragging = true }
        return dragUpdate(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragUpdate(sender)
    }

    private func dragUpdate(_ sender: NSDraggingInfo) -> NSDragOperation {
        let point = convert(sender.draggingLocation, from: nil)
        guard hasFiles(sender), triggerRect().contains(point) else {
            MainActor.assumeIsolated { viewModel.dropActive = false }
            return []
        }
        MainActor.assumeIsolated {
            viewModel.open()
            viewModel.showShelf = true
            viewModel.dropActive = true
        }
        return .copy
    }

    override func draggingExited(_: NSDraggingInfo?) {
        isDragging = false
        MainActor.assumeIsolated {
            viewModel.dropActive = false
            viewModel.scheduleClose()
        }
    }

    override func draggingEnded(_: NSDraggingInfo) {
        isDragging = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        hasFiles(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true],
        ) as? [URL], !urls.isEmpty else { return false }
        MainActor.assumeIsolated {
            viewModel.open()
            viewModel.showShelf = true
            viewModel.dropActive = false
            shelf.addFiles(urls)
        }
        return true
    }
}

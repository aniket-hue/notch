import AppKit

@MainActor
final class ShelfDropController {
    private let viewModel: NotchViewModel
    private let shelf: ShelfService
    private let panel: ShelfDropPanel
    private let view: ShelfDropView

    init(viewModel: NotchViewModel, shelf: ShelfService) {
        self.viewModel = viewModel
        self.shelf = shelf
        view = ShelfDropView()
        panel = ShelfDropPanel()
        panel.contentView = view

        view.onEnter = { [weak self] in self?.handleEnter() }
        view.onExit = { [weak self] in self?.handleExit() }
        view.onDrop = { [weak self] urls in self?.handleDrop(urls) }

        positionClosed()
        panel.orderFrontRegardless()
    }

    func updateMetrics() {
        positionClosed()
    }

    private func notchRect() -> NSRect {
        let m = viewModel.metrics
        let f = m.screen.frame
        let w = m.notchWidth + 30
        let h = m.notchHeight + 8
        return NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
    }

    private func catchRect() -> NSRect {
        let f = viewModel.metrics.screen.frame
        let w: CGFloat = 560
        let h: CGFloat = 220
        return NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
    }

    private func positionClosed() {
        panel.setFrame(notchRect(), display: false)
    }

    private func handleEnter() {
        viewModel.open()
        viewModel.showShelf = true
        viewModel.dropActive = true
        panel.setFrame(catchRect(), display: false)
    }

    private func handleExit() {
        viewModel.dropActive = false
        viewModel.collapse()
        positionClosed()
    }

    private func handleDrop(_ urls: [URL]) {
        shelf.addFiles(urls)
        viewModel.open()
        viewModel.showShelf = true
        viewModel.dropActive = false
        positionClosed()
    }
}

private final class ShelfDropPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class ShelfDropView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    var onDrop: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func hasFiles(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasFiles(sender) else { return [] }
        onEnter?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        hasFiles(sender) ? .copy : []
    }

    override func draggingExited(_: NSDraggingInfo?) {
        onExit?()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        hasFiles(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true],
        ) as? [URL], !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }
}

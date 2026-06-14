import AppKit

struct ClipItem: Identifiable, Equatable {
    enum Kind: Equatable { case text, image }
    let id = UUID()
    let kind: Kind
    let text: String?
    let image: NSImage?
    let date: Date

    static func == (a: ClipItem, b: ClipItem) -> Bool { a.id == b.id }
}

@MainActor
final class ClipboardService: ObservableObject {

    @Published private(set) var items: [ClipItem] = []

    private var cache: LRUCache<String, ClipItem>
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    init(limit: Int = 50) {
        cache = LRUCache<String, ClipItem>(capacity: limit)
    }

    func setLimit(_ value: Int) {
        cache.setCapacity(value)
        items = cache.values
    }

    func start() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        capture(pb)
    }

    private func capture(_ pb: NSPasteboard) {
        if let str = pb.string(forType: .string), !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(ClipItem(kind: .text, text: str, image: nil, date: Date()), key: "t:" + str)
        } else if let img = NSImage(pasteboard: pb) {
            let key = "i:" + (img.tiffRepresentation?.hashValue.description ?? UUID().uuidString)
            add(ClipItem(kind: .image, text: nil, image: img, date: Date()), key: key)
        }
    }

    private func add(_ item: ClipItem, key: String) {
        cache.insert(item, for: key)
        items = cache.values
    }

    func copyBack(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text:
            if let t = item.text { pb.setString(t, forType: .string) }
        case .image:
            if let img = item.image { pb.writeObjects([img]) }
        }
        lastChangeCount = pb.changeCount
        cache.touch(item.kind == .text ? "t:" + (item.text ?? "") : "i:" + (item.image?.tiffRepresentation?.hashValue.description ?? ""))
        items = cache.values
    }

    func clear() {
        cache.removeAll()
        items = cache.values
    }
}

import AppKit

struct ClipItem: Identifiable, Equatable {
    enum Kind: Equatable { case text, image }
    let id = UUID()
    let kind: Kind
    let text: String?
    let image: NSImage?
    let date: Date
    let cacheKey: String

    static func == (a: ClipItem, b: ClipItem) -> Bool { a.id == b.id }
}

private struct StoredItem: Codable {
    let kind: String
    let text: String?
    let imageData: Data?
    let date: Date
    let key: String

    init(_ item: ClipItem) {
        switch item.kind {
        case .text:
            kind = "text"
            text = item.text
            imageData = nil
        case .image:
            kind = "image"
            text = nil
            imageData = item.image?.pngData()
        }
        date = item.date
        key = item.cacheKey
    }

    func toClipItem() -> ClipItem? {
        switch kind {
        case "text":
            guard let text else { return nil }
            return ClipItem(kind: .text, text: text, image: nil, date: date, cacheKey: key)
        case "image":
            guard let imageData, let img = NSImage(data: imageData) else { return nil }
            return ClipItem(kind: .image, text: nil, image: img, date: date, cacheKey: key)
        default:
            return nil
        }
    }
}

@MainActor
final class ClipboardService: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    private var cache: LRUCache<String, ClipItem>
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let storeURL: URL?
    private let saveQueue = DispatchQueue(label: "opennook.clipboard.save")

    init(limit: Int = 50) {
        cache = LRUCache<String, ClipItem>(capacity: limit)
        storeURL = Self.makeStoreURL()
        loadPersisted()
    }

    func setLimit(_ value: Int) {
        cache.setCapacity(value)
        items = cache.values
        persist()
    }

    func start() {
        capture(NSPasteboard.general)
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
            let key = "t:" + str
            add(ClipItem(kind: .text, text: str, image: nil, date: Date(), cacheKey: key), key: key)
        } else if let img = NSImage(pasteboard: pb) {
            let key = "i:" + (img.tiffRepresentation?.hashValue.description ?? UUID().uuidString)
            add(ClipItem(kind: .image, text: nil, image: img, date: Date(), cacheKey: key), key: key)
        }
    }

    private func add(_ item: ClipItem, key: String) {
        cache.insert(item, for: key)
        items = cache.values
        persist()
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
        cache.touch(item.cacheKey)
        items = cache.values
        persist()
    }

    func clear() {
        cache.removeAll()
        items = cache.values
        persist()
    }

    private func loadPersisted() {
        guard let url = storeURL,
              let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([StoredItem].self, from: data) else { return }
        for dto in stored.reversed() {
            guard let item = dto.toClipItem() else { continue }
            cache.insert(item, for: item.cacheKey)
        }
        items = cache.values
    }

    private func persist() {
        guard let url = storeURL else { return }
        let stored = cache.values.map(StoredItem.init)
        saveQueue.async {
            guard let data = try? JSONEncoder().encode(stored) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func makeStoreURL() -> URL? {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let appDir = dir.appendingPathComponent("OpenNook", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("clipboard.json")
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

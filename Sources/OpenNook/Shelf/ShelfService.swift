import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    enum Kind: String, Codable { case file, image, link, text }
    let id: UUID
    let kind: Kind
    let url: URL?
    let text: String?
    let name: String
    let addedAt: Date
    let bytes: Int64
    var thumbnail: NSImage?
    var hasPreview: Bool

    static func == (a: ShelfItem, b: ShelfItem) -> Bool {
        a.id == b.id && a.thumbnail === b.thumbnail && a.hasPreview == b.hasPreview
    }
}

private struct StoredShelfItem: Codable {
    let id: UUID
    let kind: String
    let name: String
    let text: String?
    let addedAt: Date
    let bytes: Int64

    init(_ item: ShelfItem) {
        id = item.id
        kind = item.kind.rawValue
        name = item.name
        text = item.text
        addedAt = item.addedAt
        bytes = item.bytes
    }
}

@MainActor
final class ShelfService: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    private let dir: URL?
    private let metaURL: URL?
    private let saveQueue = DispatchQueue(label: "opennook.shelf.save")
    private let ioQueue = DispatchQueue(label: "opennook.shelf.io", qos: .userInitiated)

    private static let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tiff", "tif", "bmp"]

    init() {
        dir = Self.makeDir()
        metaURL = dir?.appendingPathComponent("shelf.json")
        load()
    }

    var count: Int {
        items.count
    }

    func addFiles(_ urls: [URL]) {
        guard let dir else { return }
        for src in urls {
            guard src.isFileURL else {
                if src.scheme != nil { addLink(src) }
                continue
            }
            ioQueue.async { [weak self] in
                guard let item = Self.stage(src, in: dir) else { return }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.items.insert(item, at: 0)
                    self.persist()
                    if let url = item.url { self.loadThumbnail(id: item.id, url: url) }
                }
            }
        }
    }

    func addLink(_ url: URL) {
        let item = ShelfItem(
            id: UUID(),
            kind: .link,
            url: nil,
            text: url.absoluteString,
            name: url.host ?? url.absoluteString,
            addedAt: Date(),
            bytes: 0,
            thumbnail: nil,
            hasPreview: false,
        )
        items.insert(item, at: 0)
        persist()
    }

    func remove(_ item: ShelfItem) {
        if let url = item.url {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        for item in items {
            if let url = item.url { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        }
        items.removeAll()
        persist()
    }

    func open(_ item: ShelfItem) {
        if let url = item.url {
            NSWorkspace.shared.open(url)
        } else if let text = item.text, let url = URL(string: text) {
            NSWorkspace.shared.open(url)
        }
    }

    func itemProvider(for item: ShelfItem) -> NSItemProvider {
        if let url = item.url, let provider = NSItemProvider(contentsOf: url) {
            return provider
        }
        if let text = item.text {
            return NSItemProvider(object: text as NSString)
        }
        return NSItemProvider()
    }

    private func loadThumbnail(id: UUID, url: URL) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 104, height: 86),
            scale: scale,
            representationTypes: .all,
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            guard let rep else { return }
            let image = rep.nsImage
            let isPreview = rep.type != .icon
            DispatchQueue.main.async {
                guard let self, let idx = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[idx].thumbnail = image
                self.items[idx].hasPreview = isPreview
            }
        }
    }

    private func load() {
        guard let metaURL, let dir,
              let data = try? Data(contentsOf: metaURL),
              let stored = try? JSONDecoder().decode([StoredShelfItem].self, from: data) else { return }
        var loaded: [ShelfItem] = []
        for dto in stored {
            let kind = ShelfItem.Kind(rawValue: dto.kind) ?? .file
            var url: URL?
            if kind == .file || kind == .image {
                let candidate = dir.appendingPathComponent(dto.id.uuidString).appendingPathComponent(dto.name)
                guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
                url = candidate
            }
            loaded.append(ShelfItem(
                id: dto.id,
                kind: kind,
                url: url,
                text: dto.text,
                name: dto.name,
                addedAt: dto.addedAt,
                bytes: dto.bytes,
                thumbnail: nil,
                hasPreview: false,
            ))
        }
        items = loaded
        for item in loaded where item.url != nil {
            loadThumbnail(id: item.id, url: item.url!)
        }
    }

    private func persist() {
        guard let metaURL else { return }
        let stored = items.map(StoredShelfItem.init)
        saveQueue.async {
            guard let data = try? JSONEncoder().encode(stored) else { return }
            try? data.write(to: metaURL, options: .atomic)
        }
    }

    private nonisolated static func stage(_ src: URL, in dir: URL) -> ShelfItem? {
        let id = UUID()
        let sub = dir.appendingPathComponent(id.uuidString, isDirectory: true)
        let staged = sub.appendingPathComponent(src.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: src, to: staged)
        } catch { return nil }
        let isImage = imageExts.contains(src.pathExtension.lowercased())
        let bytes = Int64((try? staged.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        return ShelfItem(
            id: id,
            kind: isImage ? .image : .file,
            url: staged,
            text: nil,
            name: src.lastPathComponent,
            addedAt: Date(),
            bytes: bytes,
            thumbnail: nil,
            hasPreview: false,
        )
    }

    private static func makeDir() -> URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let shelf = base.appendingPathComponent("OpenNook", isDirectory: true).appendingPathComponent("Shelf", isDirectory: true)
        try? fm.createDirectory(at: shelf, withIntermediateDirectories: true)
        return shelf
    }
}

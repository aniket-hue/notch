import AppKit
import ImageIO
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

    static func == (a: ShelfItem, b: ShelfItem) -> Bool { a.id == b.id }
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
        var added = false
        for src in urls {
            guard src.isFileURL else {
                if src.scheme != nil { addLink(src); added = true }
                continue
            }
            let id = UUID()
            let sub = dir.appendingPathComponent(id.uuidString, isDirectory: true)
            let staged = sub.appendingPathComponent(src.lastPathComponent)
            do {
                try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: src, to: staged)
            } catch { continue }
            let isImage = Self.imageExts.contains(src.pathExtension.lowercased())
            let bytes = Int64((try? staged.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            let item = ShelfItem(
                id: id,
                kind: isImage ? .image : .file,
                url: staged,
                text: nil,
                name: src.lastPathComponent,
                addedAt: Date(),
                bytes: bytes,
                thumbnail: isImage ? Self.thumbnail(staged) : nil,
            )
            items.insert(item, at: 0)
            added = true
        }
        if added { persist() }
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

    private func load() {
        guard let metaURL, let dir,
              let data = try? Data(contentsOf: metaURL),
              let stored = try? JSONDecoder().decode([StoredShelfItem].self, from: data) else { return }
        var loaded: [ShelfItem] = []
        for dto in stored {
            let kind = ShelfItem.Kind(rawValue: dto.kind) ?? .file
            var url: URL?
            var thumb: NSImage?
            if kind == .file || kind == .image {
                let candidate = dir.appendingPathComponent(dto.id.uuidString).appendingPathComponent(dto.name)
                guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
                url = candidate
                if kind == .image { thumb = Self.thumbnail(candidate) }
            }
            loaded.append(ShelfItem(
                id: dto.id,
                kind: kind,
                url: url,
                text: dto.text,
                name: dto.name,
                addedAt: dto.addedAt,
                bytes: dto.bytes,
                thumbnail: thumb,
            ))
        }
        items = loaded
    }

    private func persist() {
        guard let metaURL else { return }
        let stored = items.map(StoredShelfItem.init)
        saveQueue.async {
            guard let data = try? JSONEncoder().encode(stored) else { return }
            try? data.write(to: metaURL, options: .atomic)
        }
    }

    private static func thumbnail(_ url: URL, max: CGFloat = 220) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    private static func makeDir() -> URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let shelf = base.appendingPathComponent("OpenNook", isDirectory: true).appendingPathComponent("Shelf", isDirectory: true)
        try? fm.createDirectory(at: shelf, withIntermediateDirectories: true)
        return shelf
    }
}

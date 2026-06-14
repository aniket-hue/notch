import AppKit

struct NowPlaying: Equatable {
    var hasTrack = false
    var title = ""
    var artist = ""
    var album = ""
    var isPlaying = false
    var duration: Double = 0
    var elapsedAtAnchor: Double = 0
    var anchorEpoch: Double = 0
    var artwork: NSImage?
    var artworkID: Int = 0

    static func == (l: NowPlaying, r: NowPlaying) -> Bool {
        l.hasTrack == r.hasTrack && l.title == r.title && l.artist == r.artist &&
            l.album == r.album && l.isPlaying == r.isPlaying && l.duration == r.duration &&
            l.elapsedAtAnchor == r.elapsedAtAnchor && l.anchorEpoch == r.anchorEpoch &&
            l.artwork === r.artwork
    }

    func elapsed(at epoch: Double) -> Double {
        guard anchorEpoch > 0 else { return elapsedAtAnchor }
        let base = isPlaying ? elapsedAtAnchor + max(0, epoch - anchorEpoch) : elapsedAtAnchor
        return duration > 0 ? min(base, duration) : base
    }
}

private struct ParsedTrack {
    var cleared = false
    var title = ""
    var artist = ""
    var album = ""
    var isPlaying = false
    var duration: Double = 0
    var elapsed: Double = 0
    var anchorEpoch: Double = 0
    var artworkData: Data?
}

@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var now = NowPlaying()
    @Published private(set) var available = false

    private let plPath: String
    private let fwPath: String
    private var process: Process?
    private let parseQueue = DispatchQueue(label: "opennook.nowplaying.parse")
    private nonisolated(unsafe) var buffer = Data()
    private nonisolated(unsafe) static let iso = ISO8601DateFormatter()

    init() {
        let res = Bundle.main.resourceURL
        plPath = res?.appendingPathComponent("mediaremote-adapter.pl").path ?? ""
        fwPath = res?.appendingPathComponent("MediaRemoteAdapter.framework").path ?? ""
        let fm = FileManager.default
        available = !plPath.isEmpty && fm.fileExists(atPath: plPath) && fm.fileExists(atPath: fwPath)
    }

    func start() {
        guard available, process == nil else { return }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [plPath, fwPath, "stream", "--no-diff"]
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = Pipe()

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self, !data.isEmpty else { return }
            parseQueue.async {
                self.buffer.append(data)
                while let nl = self.buffer.firstIndex(of: 0x0A) {
                    let line = self.buffer.subdata(in: self.buffer.startIndex ..< nl)
                    self.buffer.removeSubrange(self.buffer.startIndex ... nl)
                    guard let parsed = Self.parse(line) else { continue }
                    Task { @MainActor [weak self] in self?.apply(parsed) }
                }
            }
        }

        process = p
        try? p.run()
    }

    func stop() {
        process?.terminate()
        process = nil
    }

    private func apply(_ p: ParsedTrack) {
        var n = NowPlaying()
        if p.cleared {
            now = n
            return
        }
        n.hasTrack = true
        n.title = p.title
        n.artist = p.artist
        n.album = p.album
        n.isPlaying = p.isPlaying
        n.duration = p.duration
        n.elapsedAtAnchor = p.elapsed
        n.anchorEpoch = p.anchorEpoch
        if let d = p.artworkData {
            n.artwork = NSImage(data: d)
            var hasher = Hasher()
            hasher.combine(d.count)
            hasher.combine(d.prefix(128))
            hasher.combine(d.suffix(128))
            n.artworkID = hasher.finalize()
        } else {
            n.artwork = now.artwork
            n.artworkID = now.artworkID
        }
        now = n
    }

    private nonisolated static func parse(_ data: Data) -> ParsedTrack? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
        guard let dict = obj as? [String: Any] else {
            return ParsedTrack(cleared: true)
        }
        let payload = (dict["payload"] as? [String: Any]) ?? dict
        guard let title = payload["title"] as? String, !title.isEmpty else {
            return ParsedTrack(cleared: true)
        }
        func num(_ key: String) -> Double { (payload[key] as? NSNumber)?.doubleValue ?? 0 }
        var t = ParsedTrack()
        t.title = title
        t.artist = payload["artist"] as? String ?? ""
        t.album = payload["album"] as? String ?? ""
        t.isPlaying = (payload["playing"] as? Bool) ?? false
        t.duration = num("duration")
        t.elapsed = num("elapsedTime")
        if let ts = payload["timestamp"] as? String {
            t.anchorEpoch = iso.date(from: ts)?.timeIntervalSince1970 ?? 0
        }
        if let b64 = payload["artworkData"] as? String {
            t.artworkData = Data(base64Encoded: b64)
        }
        return t
    }

    func togglePlayPause() {
        var n = now
        let live = n.elapsed(at: Date().timeIntervalSince1970)
        n.isPlaying.toggle()
        n.elapsedAtAnchor = live
        n.anchorEpoch = Date().timeIntervalSince1970
        now = n
        run(["send", "2"])
    }

    func next() { run(["send", "4"]) }
    func previous() { run(["send", "5"]) }

    func seek(to seconds: Double) {
        var n = now
        n.elapsedAtAnchor = max(0, min(seconds, n.duration))
        n.anchorEpoch = Date().timeIntervalSince1970
        now = n

        run(["seek", String(Int(max(0, seconds) * 1_000_000))])
    }

    private func run(_ args: [String]) {
        guard available else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [plPath, fwPath] + args
        try? p.run()
    }
}

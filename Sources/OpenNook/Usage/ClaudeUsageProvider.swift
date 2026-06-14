import Foundation

struct ClaudeUsageProvider: UsageProvider {
    let id = "claude"
    let displayName = "Claude"

    func snapshot() async -> UsageSnapshot {
        await Task.detached(priority: .utility) { Self.compute() }.value
    }

    private struct Rate {
        let input, output, cacheRead, cache5m, cache1h: Double
    }

    private static func rate(_ model: String) -> Rate {
        let m = model.lowercased()
        if m.contains("opus") { return Rate(input: 15, output: 75, cacheRead: 1.5, cache5m: 18.75, cache1h: 30) }
        if m.contains("haiku") { return Rate(input: 0.8, output: 4, cacheRead: 0.08, cache5m: 1.0, cache1h: 1.6) }
        return Rate(input: 3, output: 15, cacheRead: 0.3, cache5m: 3.75, cache1h: 6)
    }

    private struct Record {
        let date: Date
        let tokens: Int
        let cost: Double
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func compute() -> UsageSnapshot {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = home.appendingPathComponent(".claude/projects")
        let now = Date()
        let weekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        let fileCutoff = now.addingTimeInterval(-8 * 24 * 3600)

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
        ) else {
            return .empty()
        }

        var records: [Record] = []
        var seen = Set<String>()

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            if let mod = vals?.contentModificationDate, mod < fileCutoff { continue }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }

            content.enumerateLines { line, _ in
                guard line.contains("\"usage\"") else { return }
                guard let data = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let msg = obj["message"] as? [String: Any],
                      msg["role"] as? String == "assistant",
                      let usage = msg["usage"] as? [String: Any],
                      let tsStr = obj["timestamp"] as? String,
                      let date = iso.date(from: tsStr)
                else { return }
                guard date >= weekAgo else { return }

                let mid = (msg["id"] as? String) ?? (obj["uuid"] as? String) ?? ""
                let req = (obj["requestId"] as? String) ?? ""
                if !mid.isEmpty || !req.isEmpty {
                    let key = mid + "|" + req
                    if seen.contains(key) { return }
                    seen.insert(key)
                }

                let model = (msg["model"] as? String) ?? "sonnet"
                let tc = tokensCost(model: model, usage: usage)
                records.append(Record(date: date, tokens: tc.tokens, cost: tc.cost))
            }
        }

        guard !records.isEmpty else { return .empty() }
        records.sort { $0.date < $1.date }

        let weekTokens = records.reduce(0) { $0 + $1.tokens }
        let weekCost = records.reduce(0.0) { $0 + $1.cost }

        var blocks: [(start: Date, last: Date, tokens: Int, cost: Double)] = []
        for r in records {
            if var b = blocks.last,
               r.date < b.start.addingTimeInterval(5 * 3600),
               r.date.timeIntervalSince(b.last) <= 5 * 3600
            {
                b.last = r.date
                b.tokens += r.tokens
                b.cost += r.cost
                blocks[blocks.count - 1] = b
            } else {
                blocks.append((start: floorHour(r.date), last: r.date, tokens: r.tokens, cost: r.cost))
            }
        }

        var fiveTokens = 0
        var fiveCost = 0.0
        var resetsAt: Date?
        if let b = blocks.last {
            let end = b.start.addingTimeInterval(5 * 3600)
            if now < end {
                fiveTokens = b.tokens
                fiveCost = b.cost
                resetsAt = end
            }
        }

        let windows = [
            UsageWindow(kind: .fiveHour, title: "5-hour", tokens: fiveTokens, cost: fiveCost, resetsAt: resetsAt),
            UsageWindow(kind: .week, title: "This week", tokens: weekTokens, cost: weekCost, resetsAt: nil),
        ]
        return UsageSnapshot(providerID: id, providerName: "Claude", windows: windows, hasData: true, updatedAt: now)
    }

    private static let id = "claude"

    private static func floorHour(_ d: Date) -> Date {
        let s = d.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (s / 3600).rounded(.down) * 3600)
    }

    private static func tokensCost(model: String, usage: [String: Any]) -> (tokens: Int, cost: Double) {
        func n(_ k: String) -> Double { (usage[k] as? NSNumber)?.doubleValue ?? 0 }
        let input = n("input_tokens")
        let output = n("output_tokens")
        let cacheRead = n("cache_read_input_tokens")
        var w5 = 0.0
        var w1 = 0.0
        if let cc = usage["cache_creation"] as? [String: Any] {
            w5 = (cc["ephemeral_5m_input_tokens"] as? NSNumber)?.doubleValue ?? 0
            w1 = (cc["ephemeral_1h_input_tokens"] as? NSNumber)?.doubleValue ?? 0
        } else {
            w5 = n("cache_creation_input_tokens")
        }
        let r = rate(model)
        let cost = (input * r.input + output * r.output + cacheRead * r.cacheRead
            + w5 * r.cache5m + w1 * r.cache1h) / 1_000_000
        let tokens = Int(input + output + cacheRead + w5 + w1)
        return (tokens, cost)
    }
}

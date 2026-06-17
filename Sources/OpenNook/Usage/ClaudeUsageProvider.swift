import Foundation

struct ClaudeUsageProvider: UsageProvider {
    let id = "claude"
    let displayName = "Claude"

    func snapshot() async -> ActivitySnapshot {
        await Task.detached(priority: .utility) { Self.compute() }.value
    }

    private struct Rate {
        let input, output, cacheRead, cache5m, cache1h: Double
    }

    private static func rate(_ key: String) -> Rate {
        switch key {
        case "fable": Rate(input: 10, output: 50, cacheRead: 1.0, cache5m: 12.5, cache1h: 20)
        case "opus": Rate(input: 5, output: 25, cacheRead: 0.5, cache5m: 6.25, cache1h: 10)
        case "haiku": Rate(input: 1, output: 5, cacheRead: 0.1, cache5m: 1.25, cache1h: 2)
        default: Rate(input: 3, output: 15, cacheRead: 0.3, cache5m: 3.75, cache1h: 6)
        }
    }

    private static func modelKey(_ model: String) -> String {
        let m = model.lowercased()
        if m.contains("fable") { return "fable" }
        if m.contains("opus") { return "opus" }
        if m.contains("haiku") { return "haiku" }
        if m.contains("sonnet") { return "sonnet" }
        return "other"
    }

    private struct Msg {
        let date: Date
        let project: String
        let session: String
        let key: String
        let cost: Double
        let editFiles: [String]
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func compute() -> ActivitySnapshot {
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

        var msgs: [Msg] = []
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
                      let message = obj["message"] as? [String: Any],
                      message["role"] as? String == "assistant",
                      let usage = message["usage"] as? [String: Any],
                      let tsStr = obj["timestamp"] as? String,
                      let date = iso.date(from: tsStr)
                else { return }
                guard date >= weekAgo else { return }

                let mid = (message["id"] as? String) ?? (obj["uuid"] as? String) ?? ""
                let req = (obj["requestId"] as? String) ?? ""
                if !mid.isEmpty || !req.isEmpty {
                    let key = mid + "|" + req
                    if seen.contains(key) { return }
                    seen.insert(key)
                }

                let cwd = obj["cwd"] as? String ?? ""
                let project = cwd.isEmpty ? "—" : (cwd as NSString).lastPathComponent
                let session = obj["sessionId"] as? String ?? mid
                let key = modelKey(message["model"] as? String ?? "")
                let cost = cost(key: key, usage: usage)

                var edits: [String] = []
                if let blocks = message["content"] as? [[String: Any]] {
                    for b in blocks where b["type"] as? String == "tool_use" {
                        let name = b["name"] as? String ?? ""
                        if name == "Edit" || name == "Write" || name == "MultiEdit" || name == "NotebookEdit",
                           let input = b["input"] as? [String: Any],
                           let path = input["file_path"] as? String
                        {
                            edits.append(path)
                        }
                    }
                }

                msgs.append(Msg(date: date, project: project, session: session, key: key, cost: cost, editFiles: edits))
            }
        }

        guard !msgs.isEmpty else { return .empty() }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)

        let todayDates = msgs.filter { $0.date >= todayStart }.map(\.date).sorted()
        var activeToday = 0.0
        for i in 1 ..< max(1, todayDates.count) {
            let gap = todayDates[i].timeIntervalSince(todayDates[i - 1])
            if gap < 300 { activeToday += gap }
        }

        var dayCost = [Double](repeating: 0, count: 7)
        for m in msgs {
            let start = cal.startOfDay(for: m.date)
            let diff = cal.dateComponents([.day], from: start, to: todayStart).day ?? 99
            if diff >= 0, diff < 7 { dayCost[6 - diff] += m.cost }
        }
        let letters = cal.veryShortStandaloneWeekdaySymbols
        let days = (0 ..< 7).map { i -> DayStat in
            let date = cal.date(byAdding: .day, value: i - 6, to: todayStart) ?? todayStart
            let wd = cal.component(.weekday, from: date) - 1
            return DayStat(label: letters.indices.contains(wd) ? letters[wd] : "", cost: dayCost[i], isToday: i == 6)
        }

        var projCost: [String: Double] = [:]
        var projSessions: [String: Set<String>] = [:]
        var modelCost: [String: Double] = [:]
        var files = Set<String>()
        var sessions = Set<String>()
        var weekCost = 0.0
        for m in msgs {
            weekCost += m.cost
            projCost[m.project, default: 0] += m.cost
            projSessions[m.project, default: []].insert(m.session)
            modelCost[m.key, default: 0] += m.cost
            sessions.insert(m.session)
            for f in m.editFiles {
                files.insert(f)
            }
        }

        let projects = projCost
            .map { ProjectStat(name: $0.key, cost: $0.value, sessions: projSessions[$0.key]?.count ?? 0) }
            .sorted { $0.cost > $1.cost }
        let models = modelCost
            .map { ModelStat(key: $0.key, cost: $0.value) }
            .sorted { $0.cost > $1.cost }

        return ActivitySnapshot(
            activeTodayHours: activeToday / 3600,
            sessionsWeek: sessions.count,
            costWeek: weekCost,
            days: days,
            projects: projects,
            models: models,
            filesWeek: files.count,
            hasData: true,
            updatedAt: now,
        )
    }

    private static func cost(key: String, usage: [String: Any]) -> Double {
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
        let r = rate(key)
        return (input * r.input + output * r.output + cacheRead * r.cacheRead
            + w5 * r.cache5m + w1 * r.cache1h) / 1_000_000
    }
}

import SwiftUI

struct UsageView: View {
    @ObservedObject var service: UsageService
    @EnvironmentObject var settings: Settings

    var body: some View {
        let snap = service.snapshot
        Group {
            if snap.hasData {
                content(snap)
            } else {
                idle
            }
        }
    }

    private func content(_ snap: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            header(snap.providerName)
            ForEach(snap.windows, id: \.kind.rawValue) { meter($0) }
            Spacer(minLength: 0)
        }
    }

    private func header(_ name: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(settings.accentColor).frame(width: 7, height: 7)
            Text(name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("spend")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 0)
            Text("est. API value")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func meter(_ w: UsageWindow) -> some View {
        let budget = w.kind == .fiveHour ? settings.usageBudget5h : settings.usageBudgetWeek
        let frac = budget > 0 ? min(1, w.cost / budget) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(w.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                Text(money(w.cost))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            track(frac)
            HStack(spacing: 6) {
                Text("\(tokenStr(w.tokens)) tok")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                if budget > 0 {
                    Text("· budget \(money(budget))")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
                if let reset = w.resetsAt {
                    Text("resets in \(countdown(reset))")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private func track(_ frac: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(settings.accentColor.opacity(0.9))
                    .frame(width: max(3, geo.size.width * frac))
            }
        }
        .frame(height: 6)
    }

    private var idle: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(.white.opacity(0.05))
                Circle().strokeBorder(.white.opacity(0.06), lineWidth: 1)
                Icon(.info, size: 20, weight: 1.8)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(service.loading ? "Reading usage…" : "No Claude usage yet")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("Token usage from Claude Code shows here")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    private func money(_ v: Double) -> String {
        if v >= 100 { return "$\(Int(v.rounded()))" }
        return String(format: "$%.2f", v)
    }

    private func tokenStr(_ t: Int) -> String {
        if t >= 1_000_000 { return String(format: "%.1fM", Double(t) / 1_000_000) }
        if t >= 1000 { return String(format: "%.0fK", Double(t) / 1000) }
        return "\(t)"
    }

    private func countdown(_ date: Date) -> String {
        let s = max(0, Int(date.timeIntervalSinceNow))
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

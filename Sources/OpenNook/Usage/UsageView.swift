import SwiftUI

struct UsageView: View {
    @ObservedObject var service: UsageService
    @EnvironmentObject var settings: Settings

    var body: some View {
        let s = service.snapshot
        Group {
            if s.hasData {
                content(s)
            } else {
                idle
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func content(_ s: ActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            header(s)
            weekBars(s.days)
            VStack(alignment: .leading, spacing: 2) {
                let top = Array(s.projects.prefix(3))
                let maxCost = top.map(\.cost).max() ?? 1
                ForEach(top, id: \.name) { projectRow($0, maxCost: maxCost) }
            }
            footer(s)
            Spacer(minLength: 0)
        }
    }

    private func header(_ s: ActivitySnapshot) -> some View {
        HStack(spacing: 6) {
            Circle().fill(settings.accentColor).frame(width: 7, height: 7)
            Text("Claude")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Text(hours(s.activeTodayHours))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("today")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func weekBars(_ days: [DayStat]) -> some View {
        let maxCost = days.map(\.cost).max() ?? 1
        return VStack(spacing: 2) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(day.isToday ? settings.accentColor : Color.white.opacity(0.16))
                        .frame(height: max(3, 15 * (maxCost > 0 ? day.cost / maxCost : 0)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 15, alignment: .bottom)
            HStack(spacing: 5) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Text(day.label)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(day.isToday ? settings.accentColor : Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func projectRow(_ p: ProjectStat, maxCost: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.05))
                Capsule()
                    .fill(settings.accentColor.opacity(0.25))
                    .frame(width: max(24, geo.size.width * (maxCost > 0 ? p.cost / maxCost : 0)))
                HStack(spacing: 6) {
                    Text(p.name)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(money(p.cost))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(height: 13)
    }

    private func footer(_ s: ActivitySnapshot) -> some View {
        VStack(spacing: 4) {
            Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5)
            HStack(spacing: 7) {
                modelBar(s.models)
                Text(dominantModel(s.models))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 0)
                Text("\(s.filesWeek) files · \(money(s.costWeek)) wk")
                    .font(.system(size: 9, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func dominantModel(_ models: [ModelStat]) -> String {
        let total = models.reduce(0) { $0 + $1.cost }
        guard let top = models.first, total > 0 else { return "" }
        let pct = Int((top.cost / total * 100).rounded())
        return "\(pct)% \(top.key.prefix(1).uppercased() + top.key.dropFirst())"
    }

    private func modelBar(_ models: [ModelStat]) -> some View {
        let total = models.reduce(0) { $0 + $1.cost }
        return HStack(spacing: 1) {
            ForEach(models, id: \.key) { m in
                modelColor(m.key)
                    .frame(width: 44 * (total > 0 ? m.cost / total : 0))
            }
        }
        .frame(width: 44, height: 5)
        .clipShape(Capsule())
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
                Text(service.loading ? "Reading activity…" : "No Claude activity yet")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("Your Claude Code work shows here")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    private func modelColor(_ key: String) -> Color {
        switch key {
        case "opus": Color(red: 1.0, green: 0.62, blue: 0.30)
        case "fable": Color(red: 0.76, green: 0.52, blue: 1.0)
        case "sonnet": Color(red: 0.36, green: 0.62, blue: 1.0)
        case "haiku": Color(red: 0.30, green: 0.86, blue: 0.52)
        default: Color.gray
        }
    }

    private func hours(_ h: Double) -> String {
        if h < 1 { return "\(Int((h * 60).rounded()))m" }
        return String(format: "%.1fh", h)
    }

    private func money(_ v: Double) -> String {
        if v >= 1000 { return String(format: "$%.1fk", v / 1000) }
        if v >= 100 { return "$\(Int(v.rounded()))" }
        if v >= 10 { return String(format: "$%.1f", v) }
        return String(format: "$%.2f", v)
    }
}

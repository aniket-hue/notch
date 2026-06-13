import SwiftUI

// MARK: - Expanded System dashboard

/// The expanded "System" panel: header + Live dot, a big CPU Load number with a
/// live area/line graph, then a list of metrics — styled per the OpenNook design.
struct SystemStatsView: View {
    @ObservedObject var stats: SystemStatsService

    private var m: Metrics { stats.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            cpuLoad
            list
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private var header: some View {
        HStack {
            Text("SYSTEM")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.label)
            Spacer()
            HStack(spacing: 6) {
                LiveDot()
                Text("LIVE")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var cpuLoad: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom) {
                Text("CPU Load")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(pct(m.cpu))")
                        .font(.system(size: 24, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text("%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            CPUGraph(history: m.cpuHistory)
        }
    }

    private var list: some View {
        VStack(spacing: 12) {
            StatRow(label: "Memory",
                    value: "\(gb(m.memUsed)) / \(gb(m.memTotal))",
                    fraction: frac(Double(m.memUsed), Double(m.memTotal)))
            StatRow(label: "GPU", value: "\(pct(m.gpu))%", fraction: m.gpu)
            StatRow(label: "Storage",
                    value: "\(gb(UInt64(max(0, m.diskUsed)))) / \(gb(UInt64(max(0, m.diskTotal))))",
                    fraction: frac(Double(m.diskUsed), Double(m.diskTotal)))
            StatRow(label: "Network",
                    value: "↓ \(mbps(m.netDown))  ↑ \(mbps(m.netUp)) MB/s",
                    fraction: min(1, m.netDown / 12_000_000))
            if m.hasBattery {
                StatRow(label: "Battery",
                        value: "\(pct(m.batteryLevel))%\(m.charging ? " ⚡︎" : "")",
                        fraction: m.batteryLevel)
            }
            StatRow(label: "Uptime", value: uptime(m.uptime), fraction: nil)
        }
    }

    // MARK: Formatting

    private func pct(_ v: Double) -> Int { Int((v * 100).rounded()) }
    private func frac(_ a: Double, _ b: Double) -> Double { b > 0 ? min(1, a / b) : 0 }
    private func mbps(_ bytesPerSec: Double) -> String {
        String(format: "%.1f", bytesPerSec / 1_000_000)
    }
    private func gb(_ bytes: UInt64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useTB]
        f.countStyle = .memory
        return f.string(fromByteCount: Int64(bytes))
    }
    private func uptime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let d = total / 86400, h = (total % 86400) / 3600, min = (total % 3600) / 60
        if d > 0 { return "\(d)d \(h)h \(min)m" }
        if h > 0 { return "\(h)h \(min)m" }
        return "\(min)m"
    }
}

// MARK: - Components

/// Pulsing orange "live" indicator dot.
private struct LiveDot: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: 6, height: 6)
            .opacity(on ? 1 : 0.35)
            .scaleEffect(on ? 1 : 0.8)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

/// One label · value · thin-bar row.
private struct StatRow: View {
    let label: String
    let value: String
    var fraction: Double?

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(value)
                    .font(Theme.monoValue)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            if let fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.trackBg)
                        Capsule().fill(Theme.barFill)
                            .frame(width: max(2, geo.size.width * fraction))
                    }
                }
                .frame(height: 4)
                .animation(.easeOut(duration: 0.3), value: fraction)
            }
        }
    }
}

/// Live CPU area + line graph (orange), per the design.
private struct CPUGraph: View {
    let history: [Double]   // values 0...1

    var body: some View {
        Canvas { ctx, size in
            guard history.count > 1 else { return }
            let w = size.width, h = size.height
            let n = history.count
            var line = Path()
            for (i, v) in history.enumerated() {
                let x = w * CGFloat(i) / CGFloat(n - 1)
                let y = h - CGFloat(min(1, max(0, v))) * h
                if i == 0 { line.move(to: CGPoint(x: x, y: y)) }
                else { line.addLine(to: CGPoint(x: x, y: y)) }
            }
            var area = line
            area.addLine(to: CGPoint(x: w, y: h))
            area.addLine(to: CGPoint(x: 0, y: h))
            area.closeSubpath()

            ctx.fill(area, with: .linearGradient(
                Gradient(colors: [Theme.accent.opacity(0.38), Theme.accent.opacity(0)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: h)))
            ctx.stroke(line, with: .color(Theme.accent),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 70)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Collapsed idle hint

/// The mini live hint shown in the collapsed notch: orange CPU mini-bars + the
/// current CPU percentage, sitting to the right of the camera.
struct CollapsedHints: View {
    @ObservedObject var stats: SystemStatsService

    private var lastBars: [Double] {
        let h = stats.metrics.cpuHistory
        return Array(h.suffix(5))
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(lastBars.enumerated()), id: \.offset) { _, v in
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: 2, height: 3 + CGFloat(min(1, max(0, v))) * 11)
                    }
                }
                .frame(height: 14)
                Text("\(Int((stats.metrics.cpu * 100).rounded()))%")
                    .font(.system(size: 11, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
    }
}

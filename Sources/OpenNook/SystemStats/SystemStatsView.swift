import SwiftUI

struct SystemStatsView: View {
    @ObservedObject var stats: SystemStatsService

    @State private var hoverFrac: Double?

    private var m: Metrics { stats.metrics }
    private var memFrac: Double { m.memTotal > 0 ? Double(m.memUsed) / Double(m.memTotal) : 0 }

    private let cpuColor = Color(red: 0.36, green: 0.62, blue: 1.0)
    private let memColor = Color(red: 0.30, green: 0.86, blue: 0.52)
    private let gpuColor = Color(red: 1.0, green: 0.72, blue: 0.36)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            legend
            graph
            VStack(spacing: 4) {
                row("Network", "↓ \(mbps(m.netDown))  ↑ \(mbps(m.netUp)) MB/s")
                if m.hasBattery {
                    row("Battery", "\(pct(m.batteryLevel))%\(m.charging ? " ⚡︎" : "")")
                }
                row("Uptime", uptime(m.uptime))
            }
        }
    }

    private var hoverIndex: Int? {
        guard let f = hoverFrac, m.cpuHistory.count > 1 else { return nil }
        return Int((f * Double(m.cpuHistory.count - 1)).rounded())
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("CPU", cpuColor, value(m.cpuHistory, fallback: m.cpu))
            legendItem("MEM", memColor, value(m.memHistory, fallback: memFrac))
            legendItem("GPU", gpuColor, value(m.gpuHistory, fallback: m.gpu))
            Spacer(minLength: 0)
        }
    }

    private func legendItem(_ name: String, _ color: Color, _ v: Int) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 9, height: 2)
            Text(name)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(Theme.label)
            Text("\(v)%")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }

    private var graph: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    drawLine(ctx, m.cpuHistory, size, cpuColor)
                    drawLine(ctx, m.memHistory, size, memColor)
                    drawLine(ctx, m.gpuHistory, size, gpuColor)
                }
                if let f = hoverFrac {
                    Rectangle().fill(.white.opacity(0.3))
                        .frame(width: 1)
                        .position(x: f * geo.size.width, y: geo.size.height / 2)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): hoverFrac = min(1, max(0, p.x / geo.size.width))
                case .ended: hoverFrac = nil
                }
            }
        }
        .frame(height: 40)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func drawLine(_ ctx: GraphicsContext, _ data: [Double], _ size: CGSize, _ color: Color) {
        guard data.count > 1 else { return }
        let w = size.width, h = size.height, n = data.count
        var path = Path()
        for (i, v) in data.enumerated() {
            let x = w * CGFloat(i) / CGFloat(n - 1)
            let y = h - CGFloat(min(1, max(0, v))) * h
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }

    private func value(_ data: [Double], fallback: Double) -> Int {
        let v: Double
        if let i = hoverIndex, data.indices.contains(i) { v = data[i] } else { v = fallback }
        return Int((v * 100).rounded())
    }

    private func pct(_ v: Double) -> Int { Int((v * 100).rounded()) }
    private func mbps(_ bytesPerSec: Double) -> String {
        String(format: "%.1f", bytesPerSec / 1_000_000)
    }
    private func uptime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let d = total / 86400, h = (total % 86400) / 3600, min = (total % 3600) / 60
        if d > 0 { return "\(d)d \(h)h \(min)m" }
        if h > 0 { return "\(h)h \(min)m" }
        return "\(min)m"
    }
}

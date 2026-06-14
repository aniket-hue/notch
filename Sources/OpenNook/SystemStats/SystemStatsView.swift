import SwiftUI

struct SystemStatsView: View {
    @ObservedObject var stats: SystemStatsService
    @EnvironmentObject private var settings: Settings

    @State private var hoverFrac: Double?

    private var glass: Bool {
        settings.appearance == .glass
    }

    private var m: Metrics {
        stats.metrics
    }

    private var memFrac: Double {
        m.memTotal > 0 ? Double(m.memUsed) / Double(m.memTotal) : 0
    }

    private let cpuColor = Color(red: 0.36, green: 0.62, blue: 1.0)
    private let memColor = Color(red: 0.30, green: 0.86, blue: 0.52)
    private let gpuColor = Color(red: 1.0, green: 0.72, blue: 0.36)

    var body: some View {
        graph
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(glass ? 0.3 : 0.5), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                legend
                    .padding(.leading, 2)
                    .padding(.top, 3)
            }
            .overlay(alignment: .bottom) { statsBlock }
    }

    private var statsBlock: some View {
        VStack(spacing: 2) {
            row("Network", "↓ \(mbps(m.netDown))  ↑ \(mbps(m.netUp)) MB/s")
            row("Uptime", uptime(m.uptime))
        }
        .padding(.horizontal, 2)
        .padding(.top, 16)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(glass ? 0.55 : 0.92)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false),
        )
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
                    let baseline = Path { p in
                        p.move(to: CGPoint(x: 0, y: size.height / 2))
                        p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    }
                    ctx.stroke(baseline, with: .color(.white.opacity(0.05)), lineWidth: 1)
                    drawLine(ctx, m.memHistory, size, memColor)
                    drawLine(ctx, m.cpuHistory, size, cpuColor)
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
                case let .active(p): hoverFrac = min(1, max(0, p.x / geo.size.width))
                case .ended: hoverFrac = nil
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func graphPoints(_ data: [Double], _ size: CGSize) -> [CGPoint] {
        let w = size.width, h = size.height, n = max(1, data.count - 1)
        let inset: CGFloat = 3
        return data.enumerated().map { i, v in
            let y = inset + (1 - CGFloat(min(1, max(0, v)))) * (h - inset * 2)
            return CGPoint(x: w * CGFloat(i) / CGFloat(n), y: y)
        }
    }

    private func smoothPath(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard pts.count > 1 else { return path }
        path.move(to: pts[0])
        for i in 0 ..< pts.count - 1 {
            let p0 = i > 0 ? pts[i - 1] : pts[i]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = i + 2 < pts.count ? pts[i + 2] : p2
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    private func drawLine(_ ctx: GraphicsContext, _ data: [Double], _ size: CGSize, _ color: Color) {
        guard data.count > 1 else { return }
        let pts = graphPoints(data, size)
        let line = smoothPath(pts)

        var area = line
        area.addLine(to: CGPoint(x: size.width, y: size.height))
        area.addLine(to: CGPoint(x: 0, y: size.height))
        area.closeSubpath()
        ctx.fill(area, with: .linearGradient(
            Gradient(colors: [color.opacity(0.32), color.opacity(0)]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height),
        ))

        ctx.stroke(line, with: .color(color),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
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
        let v: Double = if let i = hoverIndex, data.indices.contains(i) { data[i] } else { fallback }
        return Int((v * 100).rounded())
    }

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

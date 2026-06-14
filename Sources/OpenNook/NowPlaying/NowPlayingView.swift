import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var service: NowPlayingService
    @EnvironmentObject var settings: Settings

    @State private var hovering = false
    @State private var dragFraction: Double?

    private let diameter: CGFloat = 120
    private let ring: CGFloat = 2
    private var ringWidth: CGFloat {
        hovering ? 4 : ring
    }

    var body: some View {
        let np = service.now
        if np.hasTrack {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                player(np, epoch: context.date.timeIntervalSince1970)
            }
        } else {
            idle
        }
    }

    private var idle: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(.white.opacity(0.05))
                Circle().strokeBorder(.white.opacity(0.06), lineWidth: 1)
                Icon(.note, size: 22, weight: 1.8)
                    .foregroundStyle(.white.opacity(0.32))
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("Nothing playing")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("Start a track to see it here")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    private func player(_ np: NowPlaying, epoch: Double) -> some View {
        let live = np.duration > 0 ? np.elapsed(at: epoch) / np.duration : 0
        let fraction = dragFraction ?? live
        return HStack(spacing: 12) {
            circle(np, fraction: fraction)
            VStack(alignment: .leading, spacing: 4) {
                Text(np.title.isEmpty ? "—" : np.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(np.artist)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Text("\(fmt(np.elapsed(at: epoch))) / \(fmt(np.duration))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    private func circle(_ np: NowPlaying, fraction: Double) -> some View {
        let inner = diameter - ring * 2
        return ZStack {
            Group {
                if let art = np.artwork {
                    Image(nsImage: art).resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.white.opacity(0.12)
                        Icon(.note, size: 26, weight: 2).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(width: inner, height: inner)
            .clipShape(Circle())

            if hovering {
                Circle().fill(.black.opacity(0.55)).frame(width: inner, height: inner)
                HStack(spacing: 9) {
                    ctrl(.prev, 18) { service.previous() }
                    ctrl(np.isPlaying ? .pause : .play, 22) { service.togglePlayPause() }
                    ctrl(.next, 18) { service.next() }
                }
            }

            Circle().stroke(Theme.trackBg, lineWidth: ringWidth)
                .frame(width: diameter - ring, height: diameter - ring)
            Circle().trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(settings.accentColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: diameter - ring, height: diameter - ring)
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .contentShape(Circle())
        .onHover { hovering = $0 }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { dragFraction = fractionFor($0.location) }
                .onEnded { value in
                    let f = fractionFor(value.location)
                    service.seek(to: f * service.now.duration)
                    dragFraction = nil
                },
        )
    }

    private func ctrl(_ icon: OIcon, _ size: CGFloat, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(icon, size: size, weight: 2)
                .foregroundStyle(.white)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func fractionFor(_ location: CGPoint) -> Double {
        let r = diameter / 2
        let x = location.x - r
        let y = location.y - r
        var theta = atan2(x, -y)
        if theta < 0 { theta += 2 * .pi }
        return min(1, max(0, theta / (2 * .pi)))
    }

    private func fmt(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let t = Int(s)
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        if h > 0 { return "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", sec))" }
        return "\(m):\(String(format: "%02d", sec))"
    }
}

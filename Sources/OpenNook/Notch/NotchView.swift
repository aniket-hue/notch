import SwiftUI

private struct NotchSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var settings: Settings
    @ObservedObject var shelf: ShelfService
    @ObservedObject var nowPlaying: NowPlayingService
    @ObservedObject var mic: MicService
    let registry: WidgetRegistry
    let onOpenSettings: () -> Void

    @State private var page: Int?

    private var pages: [LayoutConfig] {
        LayoutBuilder.pages(
            groups: settings.reconciled(available: registry.availableIDs),
            registry: registry,
        )
    }

    private var notchHeight: CGFloat {
        viewModel.metrics.notchHeight
    }

    private var openSize: CGSize {
        viewModel.openContentSize == .zero ? viewModel.closedSize : viewModel.openContentSize
    }

    private var shapeSize: CGSize {
        switch viewModel.state {
        case .open: openSize
        case .compact: viewModel.compactSize
        case .closed: viewModel.closedSize
        }
    }

    private var topRadius: CGFloat {
        switch viewModel.state {
        case .open: 12
        case .compact: 9
        case .closed: 6
        }
    }

    private var bottomRadius: CGFloat {
        switch viewModel.state {
        case .open: 22
        case .compact: 19
        case .closed: 13
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            openContent
                .opacity(viewModel.isOpen ? 1 : 0)
                .allowsHitTesting(viewModel.isOpen)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: NotchSizeKey.self, value: proxy.size)
                    },
                )
            compactContent
                .opacity(viewModel.state == .compact ? 1 : 0)
                .allowsHitTesting(false)
        }
        .frame(width: shapeSize.width, height: shapeSize.height, alignment: .top)
        .background { artTint }
        .notchSurface(
            NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius),
            glass: settings.appearance == .glass,
            tint: settings.glassTint,
        )
        .shadow(
            color: .black.opacity(viewModel.isOpen ? 0.5 : 0),
            radius: viewModel.isOpen ? 22 : 0, y: viewModel.isOpen ? 14 : 0,
        )
        .overlay(alignment: .topLeading) {
            if viewModel.isOpen {
                HStack(spacing: 0) {
                    MicButton(mic: mic)
                    clusterDivider
                    GearButton(action: onOpenSettings)
                    clusterDivider
                    ShelfButton(viewModel: viewModel, count: shelf.count, accent: settings.accentColor)
                }
                .padding(.horizontal, 5)
                .frame(height: 26)
                .background(Capsule().fill(.white.opacity(0.08)))
                .padding(.leading, 16)
                .frame(height: notchHeight, alignment: .center)
                .padding(.top, 5)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.isOpen, !viewModel.showShelf, pages.count > 1 {
                PageDots(count: pages.count, current: page ?? 0, accent: settings.accentColor) { i in
                    withAnimation(.easeInOut(duration: 0.3)) { page = i }
                }
                .padding(.trailing, 16)
                .frame(height: notchHeight, alignment: .center)
                .padding(.top, 5)
                .transition(.opacity)
            }
        }
        .onPreferenceChange(NotchSizeKey.self) { viewModel.openContentSize = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environmentObject(settings)
    }

    private var openContent: some View {
        ZStack(alignment: .top) {
            PagerView(registry: registry, pages: pages, current: $page)
                .opacity(viewModel.showShelf ? 0 : 1)
                .allowsHitTesting(!viewModel.showShelf)
            if viewModel.showShelf {
                ShelfView(service: shelf, viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showShelf)
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: notchHeight + 10) }
        .padding(.horizontal, LayoutMetrics.slotInset)
    }

    private var compactContent: some View {
        HStack(spacing: 0) {
            artThumb
            Spacer(minLength: 0)
            Waveform(active: viewModel.state == .compact && nowPlaying.now.isPlaying, color: settings.accentColor)
        }
        .padding(.horizontal, 14)
        .frame(width: viewModel.compactSize.width, height: notchHeight)
    }

    private var artThumb: some View {
        Group {
            if let art = nowPlaying.now.artwork {
                Image(nsImage: art).resizable().scaledToFill()
            } else {
                settings.accentColor.opacity(0.5)
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var clusterDivider: some View {
        Rectangle().fill(.white.opacity(0.1)).frame(width: 0.5, height: 13)
    }

    private var showArtTint: Bool {
        guard viewModel.isOpen, viewModel.artGradient.count >= 2, !pages.isEmpty else { return false }
        let index = min(max(page ?? 0, 0), pages.count - 1)
        return pages[index].items.contains { $0.widgetID == "nowPlaying" }
    }

    @ViewBuilder
    private var artTint: some View {
        if showArtTint {
            let colors = viewModel.artGradient
            artMesh(colors)
                .opacity(0.3)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.38),
                            .init(color: .clear, location: 0.92),
                        ],
                        startPoint: .leading, endPoint: .trailing,
                    ),
                )
                .clipShape(NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius))
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func artMesh(_ colors: [Color]) -> some View {
        if #available(macOS 15.0, *) {
            MeshGradient(
                width: 2, height: 2,
                points: [[0, 0], [1, 0], [0, 1], [1, 1]],
                colors: [colors[0], colors[1], colors[1], colors[0]],
            )
        } else {
            ZStack {
                colors[0]
                RadialGradient(colors: [colors[1].opacity(0.9), .clear], center: .topLeading, startRadius: 0, endRadius: 320)
                RadialGradient(colors: [colors[0].opacity(0.7), .clear], center: .bottomLeading, startRadius: 0, endRadius: 260)
            }
        }
    }
}

private struct Waveform: View {
    let active: Bool
    let color: Color
    private let bars = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0 ..< bars, id: \.self) { i in
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: height(t, i))
                }
            }
            .frame(height: 13)
        }
    }

    private func height(_ t: Double, _ i: Int) -> CGFloat {
        guard active else { return 3 }
        let v = (sin(t * 7 + Double(i) * 1.25) + 1) / 2
        return 3 + CGFloat(v) * 10
    }
}

private struct ShelfButton: View {
    @ObservedObject var viewModel: NotchViewModel
    let count: Int
    let accent: Color
    @State private var hover = false

    var body: some View {
        Button { viewModel.showShelf.toggle() } label: {
            Icon(.package, size: 14, weight: 1.8)
                .foregroundStyle(.white.opacity(viewModel.showShelf ? 0.95 : (hover ? 0.95 : 0.55)))
                .frame(width: 30, height: 24)
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 2.5)
                            .frame(minWidth: 11, minHeight: 11)
                            .background(Capsule().fill(accent))
                            .offset(x: 0, y: -2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

private struct MicButton: View {
    @ObservedObject var mic: MicService
    @State private var hover = false

    private let mutedColor = Color(red: 0.95, green: 0.42, blue: 0.40)

    var body: some View {
        if mic.available {
            Button { mic.toggle() } label: {
                Image(systemName: mic.muted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(mic.muted ? mutedColor : .white.opacity(hover ? 0.95 : 0.55))
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .onAppear { mic.refresh() }
            .help(mic.muted ? "Unmute microphone" : "Mute microphone")
            .animation(.easeOut(duration: 0.12), value: hover)
            .animation(.easeOut(duration: 0.15), value: mic.muted)
        }
    }
}

private struct GearButton: View {
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Icon(.settings, size: 14, weight: 1.8)
                .foregroundStyle(.white.opacity(hover ? 0.95 : 0.55))
                .frame(width: 30, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

extension View {
    @ViewBuilder
    func notchSurface(_ shape: NotchShape, glass: Bool, tint: Double) -> some View {
        if glass, #available(macOS 26.0, *) {
            glassEffect(.clear.tint(.black.opacity(tint)), in: shape)
        } else {
            background(Color.black).clipShape(shape)
        }
    }
}

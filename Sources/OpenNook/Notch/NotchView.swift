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
    let registry: WidgetRegistry
    let stats: SystemStatsService
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
        viewModel.isOpen ? openSize : viewModel.closedSize
    }

    private var topRadius: CGFloat {
        viewModel.isOpen ? 12 : 6
    }

    private var bottomRadius: CGFloat {
        viewModel.isOpen ? 22 : 13
    }

    var body: some View {
        openContent
            .opacity(viewModel.isOpen ? 1 : 0)
            .allowsHitTesting(viewModel.isOpen)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: NotchSizeKey.self, value: proxy.size)
                },
            )
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
                    HStack(spacing: 8) {
                        GearButton(action: onOpenSettings)
                        ShelfButton(viewModel: viewModel, count: shelf.count, accent: settings.accentColor)
                        BatteryIndicator(stats: stats)
                            .padding(.leading, 4)
                    }
                    .padding(.leading, 16)
                    .frame(height: notchHeight)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.isOpen, pages.count > 1 {
                    PageDots(count: pages.count, current: page ?? 0, accent: settings.accentColor) { i in
                        withAnimation(.easeInOut(duration: 0.3)) { page = i }
                    }
                    .padding(.trailing, 16)
                    .frame(height: notchHeight)
                    .transition(.opacity)
                }
            }
            .onPreferenceChange(NotchSizeKey.self) { viewModel.openContentSize = $0 }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environmentObject(settings)
    }

    private var openContent: some View {
        Group {
            if viewModel.showShelf {
                ShelfView(service: shelf, viewModel: viewModel)
            } else {
                PagerView(registry: registry, pages: pages, current: $page)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: notchHeight) }
        .padding(.horizontal, LayoutMetrics.slotInset)
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

private struct ShelfButton: View {
    @ObservedObject var viewModel: NotchViewModel
    let count: Int
    let accent: Color
    @State private var hover = false

    var body: some View {
        Button { viewModel.showShelf.toggle() } label: {
            Icon(.package, size: 14, weight: 1.8)
                .foregroundStyle(.white.opacity(viewModel.showShelf ? 0.95 : (hover ? 0.9 : 0.42)))
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(viewModel.showShelf ? 0.16 : (hover ? 0.14 : 0))))
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 2.5)
                            .frame(minWidth: 11, minHeight: 11)
                            .background(Capsule().fill(accent))
                            .offset(x: 1, y: -3)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

private struct GearButton: View {
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Icon(.settings, size: 14, weight: 1.8)
                .foregroundStyle(.white.opacity(hover ? 0.9 : 0.4))
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(hover ? 0.14 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

private struct BatteryIndicator: View {
    @ObservedObject var stats: SystemStatsService

    var body: some View {
        let m = stats.metrics
        if m.hasBattery {
            let level = max(0, min(1, m.batteryLevel))
            HStack(spacing: 4) {
                HStack(spacing: 1) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(.white.opacity(0.4), lineWidth: 0.9)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(fill(level, charging: m.charging))
                            .frame(width: max(1.5, 13 * level), height: 5)
                            .offset(x: 1.5)
                    }
                    .frame(width: 17, height: 9)
                    .overlay {
                        if m.charging {
                            Bolt()
                                .fill(.white)
                                .frame(width: 5, height: 7)
                        }
                    }
                    RoundedRectangle(cornerRadius: 0.8)
                        .fill(.white.opacity(0.4))
                        .frame(width: 1.5, height: 3.5)
                }
                Text("\(Int((level * 100).rounded()))%")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func fill(_ level: Double, charging: Bool) -> Color {
        if charging { return Color(red: 0.30, green: 0.86, blue: 0.52) }
        if level <= 0.2 { return Color(red: 1.0, green: 0.42, blue: 0.40) }
        return .white.opacity(0.85)
    }
}

private struct Bolt: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.58, y: 0))
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.58))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.58))
        p.addLine(to: CGPoint(x: w * 0.40, y: h))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.40))
        p.closeSubpath()
        return p
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

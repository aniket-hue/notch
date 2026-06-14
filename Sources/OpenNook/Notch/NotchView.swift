import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var settings: Settings
    let registry: WidgetRegistry
    let onOpenSettings: () -> Void

    private var pages: [LayoutConfig] {
        LayoutConfig.visible(hidden: settings.hiddenWidgets)
    }

    private var size: CGSize {
        viewModel.currentShapeSize
    }

    private var open: CGSize {
        viewModel.geometry.openSize
    }

    private var closedH: CGFloat {
        viewModel.geometry.closedHeight
    }

    private var topRadius: CGFloat {
        viewModel.isOpen ? 11 : 6
    }

    private var bottomRadius: CGFloat {
        viewModel.isOpen ? 22 : 14
    }

    var body: some View {
        ZStack(alignment: .top) {
            PagerView(registry: registry, pages: pages)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, closedH)
                .padding(.bottom, 8)
                .padding(.horizontal, 22)
                .frame(width: open.width, height: open.height, alignment: .topLeading)
                .opacity(viewModel.isOpen ? 1 : 0)
                .allowsHitTesting(viewModel.isOpen)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .notchSurface(NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius),
                      glass: settings.appearance == .glass,
                      tint: settings.glassTint)
        .shadow(color: .black.opacity(viewModel.isOpen ? 0.5 : 0),
                radius: viewModel.isOpen ? 22 : 0, y: viewModel.isOpen ? 14 : 0)
        .overlay(alignment: .bottomLeading) {
            if viewModel.isOpen {
                GearButton(action: onOpenSettings)
                    .padding(.leading, 15)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environmentObject(settings)
    }
}

private struct GearButton: View {
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Icon(.settings, size: 13, weight: 1.8)
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

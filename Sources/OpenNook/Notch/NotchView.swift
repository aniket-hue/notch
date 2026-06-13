import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    let registry: WidgetRegistry
    let pages: [LayoutConfig]

    private var size: CGSize { viewModel.currentShapeSize }
    private var open: CGSize { viewModel.geometry.openSize }
    private var closedH: CGFloat { viewModel.geometry.closedHeight }
    private var topRadius: CGFloat { viewModel.isOpen ? 11 : 6 }
    private var bottomRadius: CGFloat { viewModel.isOpen ? 22 : 14 }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black

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
        .clipShape(NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius))
        .shadow(color: .black.opacity(viewModel.isOpen ? 0.6 : 0),
                radius: viewModel.isOpen ? 22 : 0, y: viewModel.isOpen ? 14 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

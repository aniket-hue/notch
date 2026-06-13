import SwiftUI

/// The SwiftUI root inside the panel. Pure-black notch that cross-fades between a
/// collapsed live hint (CPU) and the expanded System dashboard as it grows. The
/// content is laid out at full size and revealed by the growing clip, so nothing
/// reflows mid-animation.
struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var stats: SystemStatsService

    private var size: CGSize { viewModel.currentShapeSize }
    private var open: CGSize { viewModel.geometry.openSize }
    private var closedH: CGFloat { viewModel.geometry.closedHeight }
    private var radius: CGFloat { viewModel.isOpen ? 30 : 14 }

    var body: some View {
        ZStack(alignment: .top) {
            // When collapsed, this exactly covers the physical notch (a non-display
            // region) so nothing is visible; on hover it grows into the panel.
            Color.black

            // Expanded dashboard — laid out at full open size, revealed by the clip.
            SystemStatsView(stats: stats)
                .frame(width: open.width, height: open.height, alignment: .topLeading)
                .padding(.top, closedH + 8)
                .padding(.bottom, 16)
                .opacity(viewModel.isOpen ? 1 : 0)
                .allowsHitTesting(viewModel.isOpen)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(NotchShape(bottomCornerRadius: radius))
        // Shadow ONLY when open. When collapsed, the shape covers the (non-display)
        // notch cutout invisibly — but a shadow would bleed onto the visible menu
        // bar around it, reading as a dark halo that "slides" on expand.
        .shadow(color: .black.opacity(viewModel.isOpen ? 0.55 : 0),
                radius: viewModel.isOpen ? 24 : 0, y: viewModel.isOpen ? 16 : 0)
        // Open/close is driven by HoverMonitor (absolute cursor position), not by
        // this view's hit area — so the resizing window can't cause hover jitter.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var stats: SystemStatsService
    @ObservedObject var nowPlaying: NowPlayingService

    private var size: CGSize { viewModel.currentShapeSize }
    private var open: CGSize { viewModel.geometry.openSize }
    private var closedH: CGFloat { viewModel.geometry.closedHeight }
    private var radius: CGFloat { viewModel.isOpen ? 22 : 14 }

    var body: some View {
        ZStack(alignment: .top) {

            Color.black

            HStack(alignment: .center, spacing: 18) {
                NowPlayingView(service: nowPlaying)
                    .frame(width: 230, alignment: .leading)
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 126)
                SystemStatsView(stats: stats)
                    .frame(width: 232, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.top, closedH)
            .padding(.bottom, 8)
            .padding(.horizontal, 22)
            .frame(width: open.width, height: open.height, alignment: .topLeading)
            .opacity(viewModel.isOpen ? 1 : 0)
            .allowsHitTesting(viewModel.isOpen)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(NotchShape(bottomCornerRadius: radius))

        .shadow(color: .black.opacity(viewModel.isOpen ? 0.55 : 0),
                radius: viewModel.isOpen ? 24 : 0, y: viewModel.isOpen ? 16 : 0)

        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

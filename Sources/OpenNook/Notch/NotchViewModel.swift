import Combine
import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    enum State {
        case closed
        case open
    }

    @Published var state: State = .closed
    @Published var metrics: NotchMetrics
    @Published var openContentSize: CGSize = .zero
    @Published var artGradient: [Color] = []
    @Published var showShelf = false
    @Published var dropActive = false

    private var closeWorkItem: DispatchWorkItem?

    init(metrics: NotchMetrics) {
        self.metrics = metrics
    }

    var isOpen: Bool {
        state == .open
    }

    var closedSize: CGSize {
        CGSize(width: metrics.notchWidth, height: metrics.notchHeight)
    }

    private var springAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.86)
    }

    func open() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
        guard state != .open else { return }
        withAnimation(springAnimation) {
            state = .open
        }
    }

    func scheduleClose() {
        guard state != .closed, closeWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            closeWorkItem = nil
            withAnimation(springAnimation) {
                self.state = .closed
            }
            showShelf = false
            dropActive = false
        }
        closeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}

import Combine
import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    enum State {
        case closed
        case open
    }

    @Published var state: State = .closed
    @Published var geometry: NotchGeometry

    private var closeWorkItem: DispatchWorkItem?

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    var isOpen: Bool {
        state == .open
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
        }
        closeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    var currentShapeSize: CGSize {
        switch state {
        case .closed:
            CGSize(width: geometry.closedWidth, height: geometry.closedHeight)
        case .open:
            geometry.openSize
        }
    }
}

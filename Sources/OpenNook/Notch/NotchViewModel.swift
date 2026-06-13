import SwiftUI
import Combine

/// Shared observable state for the notch UI.
@MainActor
final class NotchViewModel: ObservableObject {

    enum State {
        case closed
        case open
    }

    @Published var state: State = .closed
    @Published var geometry: NotchGeometry

    /// Debounce so brief mouse exits (e.g. crossing the rounded corners) don't flicker.
    private var closeWorkItem: DispatchWorkItem?

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    var isOpen: Bool { state == .open }

    /// One spring used for both directions, so open/close feel identical.
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
            self.closeWorkItem = nil
            withAnimation(self.springAnimation) {
                self.state = .closed
            }
        }
        closeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    /// The size of the visible black shape for the current state.
    var currentShapeSize: CGSize {
        switch state {
        case .closed:
            return CGSize(width: geometry.closedWidth, height: geometry.closedHeight)
        case .open:
            return geometry.openSize
        }
    }
}

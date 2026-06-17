import SwiftUI

struct SlotContext: Equatable {
    var inset: CGFloat
    var outerEdges: Edge.Set
    var innerEdges: Edge.Set

    static let standalone = SlotContext(inset: LayoutMetrics.slotInset, outerEdges: .all, innerEdges: [])

    static func make(index: Int, count: Int, inset: CGFloat) -> SlotContext {
        var outer: Edge.Set = [.top, .bottom]
        var inner: Edge.Set = []
        if index == 0 { outer.insert(.leading) } else { inner.insert(.leading) }
        if index == count - 1 { outer.insert(.trailing) } else { inner.insert(.trailing) }
        return SlotContext(inset: inset, outerEdges: outer, innerEdges: inner)
    }

    func bleeds(_ edge: Edge.Set) -> Bool {
        outerEdges.contains(edge)
    }

    func endBleed(_ axis: Axis) -> CGFloat {
        bleeds(axis == .horizontal ? .trailing : .bottom) ? inset : 0
    }

    func startBleed(_ axis: Axis) -> CGFloat {
        bleeds(axis == .horizontal ? .leading : .top) ? inset : 0
    }
}

extension EnvironmentValues {
    @Entry var slotContext: SlotContext = .standalone
}

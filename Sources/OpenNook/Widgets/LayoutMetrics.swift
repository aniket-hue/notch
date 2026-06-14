import SwiftUI

enum LayoutMetrics {
    static let dividerWidth: CGFloat = 1
    static let slotWidth: CGFloat = 284
    static let slotInset: CGFloat = 16

    @MainActor
    static func pageContentWidth(_ registry: WidgetRegistry, _ page: LayoutConfig) -> CGFloat {
        let count = enabledWidgets(registry, page).count
        return slotWidth * CGFloat(max(count, 1))
    }

    @MainActor
    static func maxContentWidth(_ registry: WidgetRegistry, _ pages: [LayoutConfig]) -> CGFloat {
        max(slotWidth, pages.map { pageContentWidth(registry, $0) }.max() ?? slotWidth)
    }

    @MainActor
    static func pageSize(_ registry: WidgetRegistry, _ pages: [LayoutConfig]) -> CGSize {
        let height = pages
            .flatMap { enabledWidgets(registry, $0) }
            .map(\.height)
            .max() ?? 80
        return CGSize(width: maxContentWidth(registry, pages), height: height)
    }

    @MainActor
    static func enabledWidgets(_ registry: WidgetRegistry, _ layout: LayoutConfig) -> [NotchWidget] {
        layout.items.filter(\.enabled).compactMap { registry.widget(for: $0.widgetID) }
    }
}

private struct SlotInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = LayoutMetrics.slotInset
}

extension EnvironmentValues {
    var slotInset: CGFloat {
        get { self[SlotInsetKey.self] }
        set { self[SlotInsetKey.self] = newValue }
    }
}

extension View {
    func slotBleed(_ inset: CGFloat, edges: Edge.Set = .horizontal) -> some View {
        padding(edges, -inset)
    }

    func edgeFade(_ edges: Edge.Set, _ fraction: CGFloat = 0.08) -> some View {
        mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: edges.contains(.leading) ? fraction : 0),
                    .init(color: .white, location: edges.contains(.trailing) ? 1 - fraction : 1),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing,
            ),
        )
    }
}

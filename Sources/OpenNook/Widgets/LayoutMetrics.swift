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

extension View {
    func edgeFade(_ edges: Edge.Set, _ fraction: CGFloat = 0.08) -> some View {
        let vertical = edges.contains(.top) || edges.contains(.bottom)
        let near: Edge.Set = vertical ? .top : .leading
        let far: Edge.Set = vertical ? .bottom : .trailing
        return mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: edges.contains(near) ? fraction : 0),
                    .init(color: .white, location: edges.contains(far) ? 1 - fraction : 1),
                    .init(color: .clear, location: 1),
                ],
                startPoint: vertical ? .top : .leading,
                endPoint: vertical ? .bottom : .trailing,
            ),
        )
    }
}

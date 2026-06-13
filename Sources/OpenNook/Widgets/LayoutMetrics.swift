import SwiftUI

enum LayoutMetrics {
    static let spacing: CGFloat = 18
    static let dividerWidth: CGFloat = 1
    static let hPadding: CGFloat = 22
    static let bottomPadding: CGFloat = 8
    static let topGap: CGFloat = 2
    static let dotsHeight: CGFloat = 12
    static let pageWidth: CGFloat = 520

    @MainActor
    static func pageSize(_ registry: WidgetRegistry, _ pages: [LayoutConfig]) -> CGSize {
        let height = pages
            .flatMap { enabledWidgets(registry, $0) }
            .map(\.height)
            .max() ?? 80
        return CGSize(width: pageWidth, height: height)
    }

    @MainActor
    static func enabledWidgets(_ registry: WidgetRegistry, _ layout: LayoutConfig) -> [NotchWidget] {
        layout.items.filter(\.enabled).compactMap { registry.widget(for: $0.widgetID) }
    }
}

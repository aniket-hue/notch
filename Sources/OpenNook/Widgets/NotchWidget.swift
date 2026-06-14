import SwiftUI

@MainActor
protocol NotchWidget {
    var id: String { get }
    var title: String { get }
    var height: CGFloat { get }
    func makeView() -> AnyView
}

struct LayoutItem: Codable, Identifiable {
    var widgetID: String
    var enabled: Bool = true
    var id: String {
        widgetID
    }
}

struct LayoutConfig: Codable {
    var items: [LayoutItem]
}

enum LayoutBuilder {
    @MainActor
    static func pages(groups: [[String]], registry: WidgetRegistry) -> [LayoutConfig] {
        let pages = groups
            .map { group in
                LayoutConfig(items: group
                    .filter { registry.widget(for: $0) != nil }
                    .map { LayoutItem(widgetID: $0) })
            }
            .filter { !$0.items.isEmpty }
        return pages.isEmpty ? [LayoutConfig(items: [])] : pages
    }
}

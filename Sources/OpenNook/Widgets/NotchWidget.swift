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
    var id: String { widgetID }
}

struct LayoutConfig: Codable {
    var items: [LayoutItem]

    static let pages: [LayoutConfig] = [
        LayoutConfig(items: [
            LayoutItem(widgetID: "nowPlaying"),
            LayoutItem(widgetID: "system"),
        ]),
        LayoutConfig(items: [
            LayoutItem(widgetID: "clipboard"),
        ]),
    ]
}

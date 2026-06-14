import SwiftUI

struct WidgetRow: View {
    let registry: WidgetRegistry
    let layout: LayoutConfig

    var body: some View {
        let widgets = LayoutMetrics.enabledWidgets(registry, layout)
        let dividerHeight = widgets.map(\.height).max() ?? 0

        HStack(alignment: .center, spacing: LayoutMetrics.spacing) {
            ForEach(Array(widgets.enumerated()), id: \.offset) { index, widget in
                if index > 0 {
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.12), .white.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(width: LayoutMetrics.dividerWidth, height: dividerHeight * 0.82)
                }
                widget.makeView().frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

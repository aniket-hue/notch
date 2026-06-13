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
                    Rectangle().fill(Color.white.opacity(0.08))
                        .frame(width: LayoutMetrics.dividerWidth, height: dividerHeight)
                }
                widget.makeView().frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

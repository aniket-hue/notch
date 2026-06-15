import SwiftUI

struct WidgetRow: View {
    let registry: WidgetRegistry
    let layout: LayoutConfig

    var body: some View {
        let widgets = LayoutMetrics.enabledWidgets(registry, layout)
        let rowHeight = widgets.map(\.height).max() ?? 0

        HStack(spacing: 0) {
            ForEach(Array(widgets.enumerated()), id: \.offset) { index, widget in
                widget.makeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, LayoutMetrics.slotInset)
                    .environment(\.slotContext, .make(index: index, count: widgets.count, inset: LayoutMetrics.slotInset))
            }
        }
        .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight)
        .overlay {
            if widgets.count > 1 {
                GeometryReader { geo in
                    ForEach(1 ..< widgets.count, id: \.self) { i in
                        Color.white.opacity(0.1)
                            .frame(width: LayoutMetrics.dividerWidth, height: rowHeight)
                            .position(x: geo.size.width * CGFloat(i) / CGFloat(widgets.count), y: geo.size.height / 2)
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

import SwiftUI

struct WidgetRow: View {
    let registry: WidgetRegistry
    let layout: LayoutConfig

    var body: some View {
        let widgets = LayoutMetrics.enabledWidgets(registry, layout)
        let rowHeight = widgets.map(\.height).max() ?? 0

        HStack(spacing: 0) {
            ForEach(Array(widgets.enumerated()), id: \.offset) { _, widget in
                widget.makeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, LayoutMetrics.slotInset)
                    .environment(\.slotInset, LayoutMetrics.slotInset)
            }
        }
        .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight)
        .overlay {
            if widgets.count > 1 {
                GeometryReader { geo in
                    ForEach(1 ..< widgets.count, id: \.self) { i in
                        LinearGradient(
                            colors: [.white.opacity(0), .white.opacity(0.12), .white.opacity(0)],
                            startPoint: .top, endPoint: .bottom,
                        )
                        .frame(width: LayoutMetrics.dividerWidth, height: rowHeight * 0.82)
                        .position(x: geo.size.width * CGFloat(i) / CGFloat(widgets.count), y: geo.size.height / 2)
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

import SwiftUI

struct PagerView: View {
    let registry: WidgetRegistry
    let pages: [LayoutConfig]
    @Binding var current: Int?

    private var pageSize: CGSize {
        LayoutMetrics.pageSize(registry, pages)
    }

    var body: some View {
        let size = pageSize
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 28) {
                ForEach(pages.indices, id: \.self) { i in
                    WidgetRow(registry: registry, layout: pages[i])
                        .frame(width: size.width, height: size.height)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $current)
        .frame(width: size.width, height: size.height)
    }
}

struct PageDots: View {
    let count: Int
    let current: Int
    let accent: Color
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { i in
                Button {
                    onSelect(i)
                } label: {
                    Capsule()
                        .fill(current == i ? accent : Color.white.opacity(0.22))
                        .frame(width: current == i ? 14 : 6, height: 6)
                        .padding(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeOut(duration: 0.25), value: current)
    }
}

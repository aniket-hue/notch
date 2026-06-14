import SwiftUI

struct PagerView: View {
    let registry: WidgetRegistry
    let pages: [LayoutConfig]
    @EnvironmentObject var settings: Settings

    @State private var scrolledID: Int?

    private var pageSize: CGSize {
        LayoutMetrics.pageSize(registry, pages)
    }

    private var current: Int {
        scrolledID ?? 0
    }

    var body: some View {
        let size = pageSize
        VStack(spacing: 8) {
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
            .scrollPosition(id: $scrolledID)
            .frame(width: size.width, height: size.height)

            if pages.count > 1 {
                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { i in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { scrolledID = i }
                        } label: {
                            Capsule()
                                .fill(current == i ? settings.accentColor : Color.white.opacity(0.22))
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
    }
}

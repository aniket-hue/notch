import SwiftUI

struct ClipboardView: View {
    @ObservedObject var service: ClipboardService
    @EnvironmentObject var settings: Settings

    @State private var copiedID: UUID?
    @State private var hoveredID: UUID?
    @State private var offset: CGFloat = 0

    private let cardWidth: CGFloat = 86
    private let cardHeight: CGFloat = 70
    private let cardGap: CGFloat = 9

    var body: some View {
        GeometryReader { geo in
            let viewport = geo.size.width
            let content = CGFloat(service.items.count) * (cardWidth + cardGap) - cardGap
            let maxOffset = max(0, content - viewport)
            VStack(alignment: .leading, spacing: 7) {
                header(viewport: viewport, maxOffset: maxOffset)
                if service.items.isEmpty {
                    emptyState
                } else {
                    HStack(spacing: cardGap) {
                        ForEach(service.items) { card($0) }
                    }
                    .offset(x: -min(offset, maxOffset))
                    .frame(width: viewport, alignment: .topLeading)
                    .clipped()
                }
            }
        }
    }

    private func header(viewport: CGFloat, maxOffset: CGFloat) -> some View {
        HStack(spacing: 7) {
            Text("Clipboard")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Text("\(service.items.count)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(.white.opacity(0.08)))
            Spacer()
            if maxOffset > 0 {
                navButton(.chevronLeft, enabled: offset > 1) {
                    withAnimation(.easeOut(duration: 0.25)) { offset = max(0, offset - viewport * 0.8) }
                }
                navButton(.chevronRight, enabled: offset < maxOffset - 1) {
                    withAnimation(.easeOut(duration: 0.25)) { offset = min(maxOffset, offset + viewport * 0.8) }
                }
            }
            if !service.items.isEmpty {
                Button { service.clear() } label: {
                    Icon(.trash, size: 13, weight: 1.7)
                        .foregroundStyle(Theme.textTertiary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
    }

    private func navButton(_ icon: OIcon, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(icon, size: 11, weight: 2)
                .foregroundStyle(.white.opacity(enabled ? 0.8 : 0.2))
                .frame(width: 20, height: 18)
                .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(enabled ? 0.1 : 0.03)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
            Icon(.clipboard, size: 22, weight: 1.8)
                .foregroundStyle(.white.opacity(0.18))
            Text("Nothing copied yet")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func card(_ item: ClipItem) -> some View {
        let hovered = hoveredID == item.id
        let copied = copiedID == item.id
        return Button {
            service.copyBack(item)
            copiedID = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if copiedID == item.id { copiedID = nil }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    preview(item, hovered: hovered)
                    if copied {
                        Color.black.opacity(0.5)
                        Icon(.check, size: 18, weight: 2.4)
                            .foregroundStyle(settings.accentColor)
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .scaleEffect(hovered ? 1.04 : 1.0)
                .shadow(color: .black.opacity(hovered ? 0.4 : 0), radius: 6, y: 3)
                .animation(.easeOut(duration: 0.13), value: hovered)

                Text(relativeTime(item.date))
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(width: cardWidth)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { hoveredID = item.id }
            else if hoveredID == item.id { hoveredID = nil }
        }
    }

    @ViewBuilder
    private func preview(_ item: ClipItem, hovered: Bool) -> some View {
        switch item.kind {
        case .image:
            if let img = item.image {
                Image(nsImage: img).resizable().scaledToFill()
            } else {
                placeholder(hovered)
            }
        case .text:
            ZStack(alignment: .topLeading) {
                placeholder(hovered)
                Text((item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func placeholder(_ hovered: Bool) -> some View {
        Color.white.opacity(hovered ? 0.13 : 0.07)
    }

    private func relativeTime(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 5 { return "now" }
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)d"
    }
}

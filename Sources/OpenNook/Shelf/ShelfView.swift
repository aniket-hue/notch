import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var service: ShelfService
    @ObservedObject var viewModel: NotchViewModel
    @EnvironmentObject var settings: Settings

    @State private var hoveredID: UUID?
    @State private var offset: CGFloat = 0

    private let cardWidth: CGFloat = 104
    private let cardHeight: CGFloat = 86
    private let cardGap: CGFloat = 9
    private let linkColor = Color(red: 0.36, green: 0.62, blue: 1.0)

    private let hPad: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let viewport = geo.size.width - hPad * 2
            let content = CGFloat(service.items.count) * (cardWidth + cardGap) - cardGap
            let maxOffset = max(0, content - viewport)
            let pos = min(offset, maxOffset)
            let faded: Edge.Set = (pos > 1 ? .leading : Edge.Set()).union(pos < maxOffset - 1 ? .trailing : Edge.Set())
            VStack(alignment: .leading, spacing: 6) {
                header(viewport: viewport, maxOffset: maxOffset)
                if service.items.isEmpty {
                    emptyState.frame(height: cardHeight)
                } else {
                    HStack(spacing: cardGap) {
                        ForEach(service.items) { card($0) }
                    }
                    .frame(height: cardHeight)
                    .offset(x: -pos)
                    .frame(width: viewport, height: cardHeight + 12, alignment: .leading)
                    .edgeFade(faded)
                }
            }
            .padding(.horizontal, hPad)
        }
        .frame(height: cardHeight + 40)
    }

    private func header(viewport: CGFloat, maxOffset: CGFloat) -> some View {
        HStack(spacing: 7) {
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
        let active = viewModel.dropActive
        return VStack(spacing: 8) {
            Icon(.stack, size: 22, weight: 1.8)
                .foregroundStyle(active ? settings.accentColor : .white.opacity(0.2))
            Text(active ? "Release to drop" : "Drag files here")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(active ? settings.accentColor.opacity(0.9) : Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]),
                )
                .foregroundStyle((active ? settings.accentColor : .white).opacity(active ? 0.6 : 0.12)),
        )
        .animation(.easeOut(duration: 0.15), value: active)
    }

    private func card(_ item: ShelfItem) -> some View {
        let hovered = hoveredID == item.id
        return preview(item, hovered: hovered)
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) { typeBadge(item).padding(7) }
            .overlay(alignment: .topTrailing) {
                if hovered {
                    deleteButton(item).padding(6)
                } else {
                    timePill(item.addedAt).padding(7)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.07), lineWidth: 1))
            .scaleEffect(hovered ? 1.03 : 1.0)
            .shadow(color: .black.opacity(hovered ? 0.4 : 0), radius: 6, y: 3)
            .animation(.easeOut(duration: 0.13), value: hovered)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { service.open(item) }
            .onDrag { service.itemProvider(for: item) }
            .onHover { inside in
                if inside { hoveredID = item.id }
                else if hoveredID == item.id { hoveredID = nil }
            }
    }

    @ViewBuilder
    private func preview(_ item: ShelfItem, hovered: Bool) -> some View {
        switch item.kind {
        case .image:
            if let thumb = item.thumbnail {
                Image(nsImage: thumb).resizable().scaledToFill()
            } else {
                filePreview(item, hovered: hovered)
            }
        case .file:
            filePreview(item, hovered: hovered)
        case .link:
            linkPreview(item, hovered: hovered)
        case .text:
            textPreview(item.text ?? "", hovered: hovered)
        }
    }

    private func filePreview(_ item: ShelfItem, hovered: Bool) -> some View {
        ZStack {
            placeholder(hovered)
            VStack(spacing: 6) {
                Image(nsImage: fileIcon(item))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                VStack(spacing: 1) {
                    Text(item.name)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if item.bytes > 0 {
                        Text(sizeString(item.bytes))
                            .font(.system(size: 8, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.horizontal, 6)
            }
            .padding(.top, 6)
        }
    }

    private func linkPreview(_ item: ShelfItem, hovered: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            placeholder(hovered)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(linkColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(EdgeInsets(top: 27, leading: 9, bottom: 8, trailing: 9))
        }
    }

    private func textPreview(_ raw: String, hovered: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            placeholder(hovered)
            Text(raw.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(EdgeInsets(top: 27, leading: 9, bottom: 8, trailing: 9))
        }
    }

    private func deleteButton(_ item: ShelfItem) -> some View {
        Button { service.remove(item) } label: {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(Circle().fill(.black.opacity(0.6)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func typeBadge(_ item: ShelfItem) -> some View {
        let (symbol, tint, solid) = badgeStyle(item)
        return Image(systemName: symbol)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 17, height: 17)
            .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(solid ? 0.45 : 0)))
    }

    private func badgeStyle(_ item: ShelfItem) -> (String, Color, Bool) {
        switch item.kind {
        case .image: ("photo", .white.opacity(0.85), true)
        case .file: ("doc", .white.opacity(0.55), false)
        case .link: ("link", linkColor, false)
        case .text: ("text.alignleft", .white.opacity(0.5), false)
        }
    }

    private func timePill(_ date: Date) -> some View {
        Text(relativeTime(date))
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(.black.opacity(0.4)))
    }

    private func placeholder(_ hovered: Bool) -> some View {
        Color.white.opacity(hovered ? 0.13 : 0.07)
    }

    private func fileIcon(_ item: ShelfItem) -> NSImage {
        if let url = item.url {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    private func sizeString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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

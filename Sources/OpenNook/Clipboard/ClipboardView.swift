import SwiftUI

struct ClipboardView: View {
    @ObservedObject var service: ClipboardService
    @EnvironmentObject var settings: Settings

    @Environment(\.slotInset) private var slotInset

    @State private var copiedID: UUID?
    @State private var hoveredID: UUID?
    @State private var offset: CGFloat = 0

    private let cardWidth: CGFloat = 104
    private let cardHeight: CGFloat = 86
    private let cardGap: CGFloat = 9
    private let linkColor = Color(red: 0.36, green: 0.62, blue: 1.0)
    private let codeColor = Color(red: 0.30, green: 0.86, blue: 0.52)

    private enum Category { case plain, url, color, code }

    var body: some View {
        GeometryReader { geo in
            let viewport = geo.size.width - slotInset
            let content = CGFloat(service.items.count) * (cardWidth + cardGap) - cardGap
            let maxOffset = max(0, content - viewport)
            VStack(alignment: .leading, spacing: 7) {
                header(viewport: viewport, maxOffset: maxOffset)
                    .padding(.trailing, slotInset)
                if service.items.isEmpty {
                    emptyState.padding(.trailing, slotInset)
                } else {
                    HStack(spacing: cardGap) {
                        ForEach(service.items) { card($0) }
                    }
                    .offset(x: -min(offset, maxOffset))
                    .frame(width: viewport, alignment: .topLeading)
                    .clipped()
                    .edgeFade(maxOffset > 0 ? [.leading, .trailing] : .trailing)
                }
            }
            .padding(.leading, slotInset)
        }
        .slotBleed(slotInset)
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
        let cat = category(item)
        return Button {
            service.copyBack(item)
            copiedID = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if copiedID == item.id { copiedID = nil }
            }
        } label: {
            preview(item, cat: cat, hovered: hovered)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) { typeBadge(item.kind, cat).padding(7) }
                .overlay(alignment: .topTrailing) { timePill(item.date).padding(7) }
                .overlay { if copied { copiedOverlay } }
                .scaleEffect(hovered ? 1.03 : 1.0)
                .shadow(color: .black.opacity(hovered ? 0.4 : 0), radius: 6, y: 3)
                .animation(.easeOut(duration: 0.13), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { hoveredID = item.id }
            else if hoveredID == item.id { hoveredID = nil }
        }
    }

    private var copiedOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
            Icon(.check, size: 18, weight: 2.4)
                .foregroundStyle(settings.accentColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private func typeBadge(_ kind: ClipItem.Kind, _ cat: Category) -> some View {
        let (symbol, tint) = badgeStyle(kind, cat)
        return Image(systemName: symbol)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 17, height: 17)
            .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(kind == .image ? 0.45 : 0)))
    }

    private func badgeStyle(_ kind: ClipItem.Kind, _ cat: Category) -> (String, Color) {
        if kind == .image { return ("photo", .white.opacity(0.85)) }
        switch cat {
        case .url: return ("link", linkColor)
        case .color: return ("paintpalette", .white.opacity(0.7))
        case .code: return ("curlybraces", codeColor)
        case .plain: return ("text.alignleft", .white.opacity(0.45))
        }
    }

    @ViewBuilder
    private func preview(_ item: ClipItem, cat: Category, hovered: Bool) -> some View {
        switch item.kind {
        case .image:
            if let img = item.image {
                Image(nsImage: img).resizable().scaledToFill()
            } else {
                placeholder(hovered)
            }
        case .text:
            let raw = item.text ?? ""
            switch cat {
            case .color: colorPreview(raw, hovered: hovered)
            case .url: urlPreview(raw, hovered: hovered)
            case .code: textPreview(raw, mono: true, color: codeColor.opacity(0.95), hovered: hovered)
            case .plain: textPreview(raw, mono: false, color: .white.opacity(0.85), hovered: hovered)
            }
        }
    }

    private func textPreview(_ raw: String, mono: Bool, color: Color, hovered: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            placeholder(hovered)
            Text(raw.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 10, design: mono ? .monospaced : .rounded))
                .foregroundStyle(color)
                .lineSpacing(1.5)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(EdgeInsets(top: 27, leading: 9, bottom: 8, trailing: 9))
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.72),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom,
                    ),
                )
        }
    }

    private func urlPreview(_ raw: String, hovered: Bool) -> some View {
        let (host, path) = splitURL(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        return ZStack(alignment: .topLeading) {
            placeholder(hovered)
            VStack(alignment: .leading, spacing: 2) {
                Text(host)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(linkColor)
                    .lineLimit(1)
                if !path.isEmpty {
                    Text(path)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(EdgeInsets(top: 27, leading: 9, bottom: 8, trailing: 9))
        }
    }

    private func colorPreview(_ raw: String, hovered: Bool) -> some View {
        let hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return ZStack {
            placeholder(hovered)
            VStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: hex) ?? .gray)
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.15), lineWidth: 1))
                Text(hex.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private func placeholder(_ hovered: Bool) -> some View {
        Color.white.opacity(hovered ? 0.13 : 0.07)
    }

    private func category(_ item: ClipItem) -> Category {
        guard item.kind == .text, let raw = item.text else { return .plain }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if isHexColor(t) { return .color }
        if isURL(t) { return .url }
        if looksLikeCode(raw) { return .code }
        return .plain
    }

    private func isHexColor(_ s: String) -> Bool {
        guard s.hasPrefix("#") else { return false }
        let h = s.dropFirst()
        return [3, 4, 6, 8].contains(h.count) && h.allSatisfy(\.isHexDigit)
    }

    private func isURL(_ s: String) -> Bool {
        guard !s.contains(" "), !s.contains("\n") else { return false }
        let l = s.lowercased()
        return l.hasPrefix("http://") || l.hasPrefix("https://") || l.hasPrefix("www.")
    }

    private func looksLikeCode(_ s: String) -> Bool {
        if s.range(of: #"\bfunc\b|\bdef\b|\bfunction\b|#include|<\?php|=>"#, options: .regularExpression) != nil { return true }
        let braces = s.contains("{") && s.contains("}")
        let semi = s.contains(";")
        let symbols = s.count(where: { "{}();[]<>".contains($0) })
        return (braces || semi) && symbols >= 3
    }

    private func splitURL(_ s: String) -> (String, String) {
        var rest = s
        for p in ["https://", "http://"] where rest.lowercased().hasPrefix(p) {
            rest.removeFirst(p.count)
            break
        }
        if rest.lowercased().hasPrefix("www.") { rest.removeFirst(4) }
        if let slash = rest.firstIndex(of: "/") {
            return (String(rest[..<slash]), String(rest[slash...]))
        }
        return (rest, "")
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

private extension Color {
    init?(hex: String) {
        var h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        if h.count == 4 { h = h.map { "\($0)\($0)" }.joined() }
        guard let v = UInt64(h, radix: 16) else { return nil }
        let r, g, b, a: Double
        switch h.count {
        case 6:
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        case 8:
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        default:
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

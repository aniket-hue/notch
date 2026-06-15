import SwiftUI

private struct GHScrollYKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct GHContentHKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct GHViewportHKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct GitHubPRsView: View {
    @ObservedObject var service: GitHubService
    @EnvironmentObject var settings: Settings
    @State private var copied: String?
    @State private var scrollY: CGFloat = 0
    @State private var contentH: CGFloat = 0
    @State private var viewportH: CGFloat = 0

    private let green = Color(red: 0.40, green: 0.89, blue: 0.60)
    private let red = Color(red: 0.95, green: 0.45, blue: 0.42)
    private let amber = Color(red: 1.0, green: 0.74, blue: 0.38)

    private var review: [PullRequest] {
        service.prs.filter { $0.kind == .review }
    }

    private var mine: [PullRequest] {
        service.prs.filter { $0.kind == .mine }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch service.status {
            case .needsToken:
                message("Connect GitHub", "Add a token in Settings → GitHub")
            case let .error(text):
                message("Couldn't load PRs", text)
            default:
                feed
            }
        }
        .onAppear { service.refresh() }
    }

    @ViewBuilder
    private var feed: some View {
        if review.isEmpty, mine.isEmpty {
            if service.status == .loading {
                loadingState
            } else {
                message("All caught up", "No pull requests need you")
            }
        } else {
            let scrolled = scrollY < -1
            let moreBelow = (contentH - viewportH + scrollY) > 1
            let faded: Edge.Set = (scrolled ? .top : Edge.Set()).union(moreBelow ? .bottom : Edge.Set())
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(review) { row($0) }
                    if !review.isEmpty, !mine.isEmpty {
                        Color.clear.frame(height: 12)
                    }
                    ForEach(mine) { row($0) }
                }
                .background(GeometryReader { g in
                    Color.clear
                        .preference(key: GHScrollYKey.self, value: g.frame(in: .named("ghScroll")).minY)
                        .preference(key: GHContentHKey.self, value: g.size.height)
                })
            }
            .coordinateSpace(name: "ghScroll")
            .background(GeometryReader { g in
                Color.clear.preference(key: GHViewportHKey.self, value: g.size.height)
            })
            .onPreferenceChange(GHScrollYKey.self) { scrollY = $0 }
            .onPreferenceChange(GHContentHKey.self) { contentH = $0 }
            .onPreferenceChange(GHViewportHKey.self) { viewportH = $0 }
            .edgeFade(faded, 0.12)
        }
    }

    private var loadingState: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ pr: PullRequest) -> some View {
        HStack(spacing: 11) {
            avatar(pr)
            VStack(alignment: .leading, spacing: 3) {
                Button { copyLink(pr) } label: {
                    Text(pr.title)
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Copy link")
                metaLine(pr)
            }
            Spacer(minLength: 6)
            if pr.kind == .review {
                approveButton(pr)
            }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { service.open(pr) }
        .draggable(pr.url)
    }

    private func copyLink(_ pr: PullRequest) {
        service.copyLink(pr)
        copied = pr.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copied == pr.id { copied = nil }
        }
    }

    private func metaLine(_ pr: PullRequest) -> some View {
        HStack(spacing: 7) {
            if copied == pr.id {
                Icon(.check, size: 11, weight: 2.4).foregroundStyle(green)
                Text("Link copied")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(green)
            } else {
                Text(verbatim: "\(pr.repoShort) · #\(pr.number) · \(ago(pr.updatedAt))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .layoutPriority(1)
                ciInline(pr.ci)
                if pr.kind == .mine { reviewInline(pr.review) }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func ciInline(_ ci: PullRequest.CI) -> some View {
        switch ci {
        case .pass:
            Icon(.checkCircle, size: 13, weight: 2).foregroundStyle(green)
        case .fail:
            Icon(.xCircle, size: 13, weight: 2).foregroundStyle(red)
        case .pending:
            Circle().strokeBorder(amber, lineWidth: 1.5).frame(width: 10, height: 10)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func reviewInline(_ review: PullRequest.Review) -> some View {
        switch review {
        case .approved: dotText("Approved", green)
        case .changes: dotText("Changes", red)
        case .pending: dotText("In review", amber)
        case .none: EmptyView()
        }
    }

    private func dotText(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func approveButton(_ pr: PullRequest) -> some View {
        Button { service.approve(pr) } label: {
            HStack(spacing: 5) {
                if service.approving.contains(pr.id) {
                    ProgressView().controlSize(.mini).scaleEffect(0.55).frame(width: 12, height: 12)
                } else {
                    Icon(.check, size: 11, weight: 2.4)
                }
                Text("Approve").font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(green)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().strokeBorder(green.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func avatar(_ pr: PullRequest) -> some View {
        AsyncImage(url: pr.avatarURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Circle().fill(.white.opacity(0.1))
                Text(String(pr.author.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    private func message(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Text(subtitle)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ago(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "now" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)d"
    }
}

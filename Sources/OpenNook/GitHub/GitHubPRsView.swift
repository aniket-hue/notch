import SwiftUI

private let ghGreen = Color(red: 0.40, green: 0.89, blue: 0.60)
private let ghRed = Color(red: 0.95, green: 0.45, blue: 0.42)
private let ghAmber = Color(red: 1.0, green: 0.74, blue: 0.38)

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
    @State private var scrollY: CGFloat = 0
    @State private var contentH: CGFloat = 0
    @State private var viewportH: CGFloat = 0

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
                    ForEach(review) { PRRow(pr: $0, service: service) }
                    if !review.isEmpty, !mine.isEmpty {
                        sectionDivider
                    }
                    ForEach(mine) { PRRow(pr: $0, service: service) }
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

    private var sectionDivider: some View {
        HStack(spacing: 8) {
            Text("MINE")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.3))
            Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
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
}

private struct PRRow: View {
    let pr: PullRequest
    let service: GitHubService
    @EnvironmentObject var settings: Settings

    @State private var hovered = false
    @State private var copied = false
    @State private var expanded = false
    @State private var approvePending = false
    @State private var approveWork: DispatchWorkItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                avatar
                VStack(alignment: .leading, spacing: 3) {
                    Button { copyLink() } label: {
                        Text(pr.title)
                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Copy link")
                    metaLine
                }
                Spacer(minLength: 6)
                if pr.kind == .review {
                    rightAction.frame(minWidth: 26, alignment: .trailing)
                }
            }
            if expanded, !pr.checks.isEmpty {
                checksPanel
                    .padding(.leading, 41)
                    .padding(.top, 7)
            }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { service.open(pr) }
        .onHover { hovered = $0 }
        .draggable(pr.url)
    }

    @ViewBuilder
    private var rightAction: some View {
        if approvePending {
            Button { undo() } label: {
                HStack(spacing: 5) {
                    Text("Approving")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(ghGreen.opacity(0.85))
                    Text("Undo")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(settings.accentColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.07)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        } else if service.approving.contains(pr.id) {
            ProgressView().controlSize(.mini).scaleEffect(0.6).frame(width: 22, height: 22)
        } else if hovered {
            Button { startApprove() } label: {
                Icon(.check, size: 12, weight: 2.6)
                    .foregroundStyle(ghGreen)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(ghGreen.opacity(0.14))
                            .overlay(Circle().strokeBorder(ghGreen.opacity(0.4), lineWidth: 1)),
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Approve")
            .transition(.opacity)
        }
    }

    private func startApprove() {
        approveWork?.cancel()
        approvePending = true
        let work = DispatchWorkItem {
            approvePending = false
            service.approve(pr)
        }
        approveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    private func undo() {
        approveWork?.cancel()
        approveWork = nil
        approvePending = false
    }

    private func copyLink() {
        service.copyLink(pr)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    private var metaLine: some View {
        HStack(spacing: 7) {
            if copied {
                Icon(.check, size: 11, weight: 2.4).foregroundStyle(ghGreen)
                Text("Link copied")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(ghGreen)
            } else {
                Text(verbatim: "\(pr.repoShort) · #\(pr.number) · \(ago(pr.updatedAt))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .layoutPriority(1)
                ciButton
                if pr.kind == .mine { reviewInline(pr.review) }
            }
            Spacer(minLength: 0)
        }
    }

    private var ciButton: some View {
        let expandable = !pr.checks.isEmpty
        return Button {
            if expandable { withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() } }
        } label: {
            HStack(spacing: 4) {
                ciGlyph(pr.ci).frame(width: 11, height: 11)
                if let text = ciCountText {
                    Text(text)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ciColor)
                }
                if expandable {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(ciColor.opacity(0.8))
                }
            }
            .frame(height: 14)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(ciColor.opacity(0.16)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!expandable)
    }

    private var ciColor: Color {
        switch pr.ci {
        case .pass: ghGreen
        case .fail: ghRed
        case .pending: ghAmber
        case .none: .white.opacity(0.3)
        }
    }

    private var ciCountText: String? {
        let total = pr.checks.count
        guard total > 0 else { return nil }
        let failed = pr.checks.count(where: { $0.state == .fail })
        let done = pr.checks.count(where: { $0.state == .pass || $0.state == .fail || $0.state == .skipped })
        switch pr.ci {
        case .pass: return "\(total)"
        case .fail: return "\(failed)"
        case .pending: return "\(done)/\(total)"
        case .none: return nil
        }
    }

    @ViewBuilder
    private func ciGlyph(_ ci: PullRequest.CI) -> some View {
        switch ci {
        case .pass: Icon(.checkCircle, size: 11, weight: 2.2).foregroundStyle(ghGreen)
        case .fail: Icon(.xCircle, size: 11, weight: 2.2).foregroundStyle(ghRed)
        case .pending: Circle().strokeBorder(ghAmber, lineWidth: 1.5).frame(width: 9, height: 9)
        case .none: Text("–").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.4))
        }
    }

    private var checksPanel: some View {
        let rank: (PullRequest.CheckState) -> Int = { s in
            switch s {
            case .fail: 0
            case .running: 1
            case .pending: 2
            case .pass: 3
            case .skipped: 4
            }
        }
        let sorted = pr.checks.enumerated().sorted {
            rank($0.element.state) != rank($1.element.state)
                ? rank($0.element.state) < rank($1.element.state)
                : $0.offset < $1.offset
        }.map(\.element)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, check in
                if index > 0 {
                    Rectangle().fill(.white.opacity(0.05)).frame(height: 0.5)
                }
                checkRow(check)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
        .padding(.trailing, 4)
    }

    private func checkRow(_ check: PullRequest.Check) -> some View {
        Button {
            if let url = check.url { service.openURL(url) }
        } label: {
            HStack(spacing: 8) {
                checkGlyph(check.state)
                Text(check.name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(nameColor(check.state))
                    .lineLimit(1)
                Spacer(minLength: 6)
                checkTrailing(check)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(check.url == nil)
    }

    private func nameColor(_ state: PullRequest.CheckState) -> Color {
        switch state {
        case .fail: Color(red: 0.99, green: 0.66, blue: 0.66)
        case .skipped: .white.opacity(0.38)
        default: .white.opacity(0.9)
        }
    }

    @ViewBuilder
    private func checkTrailing(_ check: PullRequest.Check) -> some View {
        switch check.state {
        case .fail where check.url != nil:
            HStack(spacing: 3) {
                Text("View log").font(.system(size: 10.5, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(ghRed)
        case .running:
            Text("running").font(.system(size: 10.5, weight: .medium, design: .rounded)).foregroundStyle(ghAmber)
        case .pending:
            Text("queued").font(.system(size: 10.5, weight: .medium, design: .rounded)).foregroundStyle(ghAmber.opacity(0.85))
        case .skipped:
            Text("skipped").font(.system(size: 10.5, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.3))
        default:
            if let duration = check.duration {
                Text(duration)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    @ViewBuilder
    private func checkGlyph(_ state: PullRequest.CheckState) -> some View {
        switch state {
        case .pass: Icon(.check, size: 10, weight: 2.4).foregroundStyle(ghGreen).frame(width: 12)
        case .fail: Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(ghRed).frame(width: 12)
        case .running: Circle().trim(from: 0, to: 0.7).stroke(ghAmber, lineWidth: 1.6).frame(width: 10, height: 10)
        case .pending: Circle().strokeBorder(ghAmber.opacity(0.6), lineWidth: 1.6).frame(width: 10, height: 10)
        case .skipped: Circle().fill(.white.opacity(0.25)).frame(width: 6, height: 6).frame(width: 12)
        }
    }

    @ViewBuilder
    private func reviewInline(_ review: PullRequest.Review) -> some View {
        switch review {
        case .approved: dotText("Approved", ghGreen)
        case .changes: dotText("Changes", ghRed)
        case .pending: dotText("In review", ghAmber)
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

    private var avatar: some View {
        CachedAvatar(url: pr.avatarURL, fallback: String(pr.author.prefix(1)).uppercased())
    }

    private func ago(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "now" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)d"
    }
}

private enum AvatarCache {
    static let shared = NSCache<NSURL, NSImage>()
}

private struct CachedAvatar: View {
    let url: URL?
    let fallback: String
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(.white.opacity(0.1))
                Text(fallback)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else { return }
        if let cached = AvatarCache.shared.object(forKey: url as NSURL) {
            image = cached
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = NSImage(data: data) else { return }
        AvatarCache.shared.setObject(img, forKey: url as NSURL)
        image = img
    }
}

import SwiftUI

@MainActor
struct NowPlayingWidget: NotchWidget {
    let id = "nowPlaying"
    let title = "Now Playing"
    let height: CGFloat = 120
    let service: NowPlayingService

    func makeView() -> AnyView {
        AnyView(NowPlayingView(service: service))
    }
}

@MainActor
struct SystemWidget: NotchWidget {
    let id = "system"
    let title = "System"
    let height: CGFloat = 120
    let service: SystemStatsService

    func makeView() -> AnyView {
        AnyView(SystemStatsView(stats: service))
    }
}

@MainActor
struct UsageWidget: NotchWidget {
    let id = "usage"
    let title = "Usage"
    let height: CGFloat = 120
    let service: UsageService

    func makeView() -> AnyView {
        AnyView(UsageView(service: service))
    }
}

@MainActor
struct ClipboardWidget: NotchWidget {
    let id = "clipboard"
    let title = "Clipboard"
    let height: CGFloat = 120
    let service: ClipboardService

    func makeView() -> AnyView {
        AnyView(ClipboardView(service: service))
    }
}

@MainActor
struct CalendarWidget: NotchWidget {
    let id = "calendar"
    let title = "Calendar"
    let height: CGFloat = 120
    let service: CalendarService

    func makeView() -> AnyView {
        AnyView(CalendarView(service: service))
    }
}

@MainActor
struct GitHubWidget: NotchWidget {
    let id = "github"
    let title = "Pull Requests"
    let height: CGFloat = 120
    let service: GitHubService

    func makeView() -> AnyView {
        AnyView(GitHubPRsView(service: service))
    }
}

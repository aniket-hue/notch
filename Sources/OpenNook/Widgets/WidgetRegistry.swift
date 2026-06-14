import Foundation

@MainActor
final class WidgetRegistry {
    private let stats: SystemStatsService
    private let nowPlaying: NowPlayingService
    private let clipboard: ClipboardService
    private let calendar: CalendarService
    private let github: GitHubService
    private let usage: UsageService

    let availableIDs = ["nowPlaying", "system", "usage", "clipboard", "calendar", "github"]

    init(stats: SystemStatsService, nowPlaying: NowPlayingService, clipboard: ClipboardService, calendar: CalendarService, github: GitHubService, usage: UsageService) {
        self.stats = stats
        self.nowPlaying = nowPlaying
        self.clipboard = clipboard
        self.calendar = calendar
        self.github = github
        self.usage = usage
    }

    func widget(for id: String) -> NotchWidget? {
        switch id {
        case "nowPlaying": NowPlayingWidget(service: nowPlaying)
        case "system": SystemWidget(service: stats)
        case "usage": UsageWidget(service: usage)
        case "clipboard": ClipboardWidget(service: clipboard)
        case "calendar": CalendarWidget(service: calendar)
        case "github": GitHubWidget(service: github)
        default: nil
        }
    }

    func title(for id: String) -> String {
        widget(for: id)?.title ?? id
    }
}

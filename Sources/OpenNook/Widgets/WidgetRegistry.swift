import Foundation

@MainActor
final class WidgetRegistry {
    private let stats: SystemStatsService
    private let nowPlaying: NowPlayingService
    private let clipboard: ClipboardService
    private let calendar: CalendarService

    let availableIDs = ["nowPlaying", "system", "clipboard", "calendar"]

    init(stats: SystemStatsService, nowPlaying: NowPlayingService, clipboard: ClipboardService, calendar: CalendarService) {
        self.stats = stats
        self.nowPlaying = nowPlaying
        self.clipboard = clipboard
        self.calendar = calendar
    }

    func widget(for id: String) -> NotchWidget? {
        switch id {
        case "nowPlaying": NowPlayingWidget(service: nowPlaying)
        case "system": SystemWidget(service: stats)
        case "clipboard": ClipboardWidget(service: clipboard)
        case "calendar": CalendarWidget(service: calendar)
        default: nil
        }
    }

    func title(for id: String) -> String {
        widget(for: id)?.title ?? id
    }
}

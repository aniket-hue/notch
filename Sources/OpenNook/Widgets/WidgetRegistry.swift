import Foundation

@MainActor
final class WidgetRegistry {
    private let stats: SystemStatsService
    private let nowPlaying: NowPlayingService
    private let clipboard: ClipboardService

    let availableIDs = ["nowPlaying", "system", "clipboard"]

    init(stats: SystemStatsService, nowPlaying: NowPlayingService, clipboard: ClipboardService) {
        self.stats = stats
        self.nowPlaying = nowPlaying
        self.clipboard = clipboard
    }

    func widget(for id: String) -> NotchWidget? {
        switch id {
        case "nowPlaying": return NowPlayingWidget(service: nowPlaying)
        case "system": return SystemWidget(service: stats)
        case "clipboard": return ClipboardWidget(service: clipboard)
        default: return nil
        }
    }

    func title(for id: String) -> String {
        widget(for: id)?.title ?? id
    }
}

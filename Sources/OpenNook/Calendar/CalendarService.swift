import AppKit
import EventKit
import SwiftUI

struct CalEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let location: String?
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color
    let meetingURL: URL?

    static func == (a: CalEvent, b: CalEvent) -> Bool {
        a.id == b.id && a.title == b.title && a.start == b.start && a.end == b.end
    }
}

enum CalAuth {
    case unknown, authorized, denied
}

@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var events: [CalEvent] = []
    @Published private(set) var auth: CalAuth = .unknown
    @Published private(set) var selectedDate = Date()

    private let store = EKEventStore()

    func start() {
        syncAuth()
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main,
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncAuth(); self?.reload() }
        }
        reload()
    }

    func ensureAccess() {
        syncAuth()
        guard auth == .unknown else { reload(); return }
        requestAccess()
    }

    private func syncAuth() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: auth = .unknown
        case .fullAccess, .authorized: auth = .authorized
        default: auth = .denied
        }
    }

    func select(_ date: Date) {
        selectedDate = date
        reload()
    }

    func resetToToday() {
        selectedDate = Date()
        reload()
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private func requestAccess() {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            let handler: (Bool, Error?) -> Void = { granted, _ in
                Task { @MainActor in
                    self.auth = granted ? .authorized : .denied
                    self.reload()
                    NSApp.setActivationPolicy(previousPolicy)
                }
            }
            if #available(macOS 14.0, *) {
                store.requestFullAccessToEvents(completion: handler)
            } else {
                store.requestAccess(to: .event, completion: handler)
            }
        }
    }

    private func reload() {
        guard auth == .authorized else { events = []; return }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDate)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return }
        let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { e in
                CalEvent(
                    id: e.eventIdentifier ?? UUID().uuidString,
                    title: (e.title?.isEmpty == false ? e.title! : "Untitled"),
                    location: e.location?.isEmpty == false ? e.location : nil,
                    start: e.startDate,
                    end: e.endDate,
                    isAllDay: e.isAllDay,
                    color: Color(nsColor: e.calendar.color ?? .systemGray),
                    meetingURL: Self.meetingURL(for: e),
                )
            }
    }

    private static let meetingHosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "around.co", "meet.jit.si",
    ]

    private static func meetingURL(for e: EKEvent) -> URL? {
        if let u = e.url, isMeeting(u) { return u }
        let text = [e.location, e.notes].compactMap(\.self).joined(separator: "\n")
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            if let u = match.url, isMeeting(u) { return u }
        }
        return nil
    }

    private static func isMeeting(_ u: URL) -> Bool {
        guard let host = u.host?.lowercased() else { return false }
        return meetingHosts.contains { host.contains($0) }
    }
}

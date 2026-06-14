import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case glass, solid
    var id: String {
        rawValue
    }

    var label: String {
        self == .glass ? "Glass" : "Solid"
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, yellow, green, teal, mono
    var id: String {
        rawValue
    }

    var color: Color {
        switch self {
        case .blue: Color(red: 0.30, green: 0.66, blue: 1.0)
        case .indigo: Color(red: 0.55, green: 0.56, blue: 1.0)
        case .purple: Color(red: 0.76, green: 0.52, blue: 1.0)
        case .pink: Color(red: 1.0, green: 0.42, blue: 0.72)
        case .red: Color(red: 1.0, green: 0.45, blue: 0.42)
        case .orange: Color(red: 1.0, green: 0.62, blue: 0.30)
        case .yellow: Color(red: 1.0, green: 0.82, blue: 0.35)
        case .green: Color(red: 0.38, green: 0.86, blue: 0.52)
        case .teal: Color(red: 0.27, green: 0.85, blue: 0.81)
        case .mono: Color.white
        }
    }
}

@MainActor
final class Settings: ObservableObject {
    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var accent: AccentChoice {
        didSet { defaults.set(accent.rawValue, forKey: Keys.accent) }
    }

    @Published var glassTint: Double {
        didSet { defaults.set(glassTint, forKey: Keys.glassTint) }
    }

    @Published var clipboardLimit: Int {
        didSet { defaults.set(clipboardLimit, forKey: Keys.clipboardLimit) }
    }

    @Published var usageBudget5h: Double {
        didSet { defaults.set(usageBudget5h, forKey: Keys.usageBudget5h) }
    }

    @Published var usageBudgetWeek: Double {
        didSet { defaults.set(usageBudgetWeek, forKey: Keys.usageBudgetWeek) }
    }

    @Published var hiddenWidgets: Set<String> {
        didSet { defaults.set(Array(hiddenWidgets), forKey: Keys.hiddenWidgets) }
    }

    @Published var layout: [[String]] {
        didSet {
            if let data = try? JSONEncoder().encode(layout) { defaults.set(data, forKey: Keys.layout) }
        }
    }

    static let defaultLayout: [[String]] = [["nowPlaying", "system"], ["usage"], ["clipboard"], ["calendar"]]

    var accentColor: Color {
        accent.color
    }

    func isWidgetEnabled(_ id: String) -> Bool { !hiddenWidgets.contains(id) }

    func reconciled(available: [String]) -> [[String]] {
        let known = Set(available)
        var pages = layout.map { page in page.filter { known.contains($0) && !hiddenWidgets.contains($0) } }
        let placed = Set(pages.flatMap(\.self))
        for id in available where !placed.contains(id) && !hiddenWidgets.contains(id) {
            pages.append([id])
        }
        return pages.filter { !$0.isEmpty }
    }

    func hiddenChips(available: [String]) -> [String] {
        available.filter { hiddenWidgets.contains($0) }
    }

    func setPages(_ pages: [[String]]) {
        layout = pages.filter { !$0.isEmpty }
    }

    func moveToPage(_ id: String, page: Int, available: [String]) {
        hiddenWidgets.remove(id)
        var pages = reconciled(available: available).map { $0.filter { $0 != id } }
        if page >= 0, page < pages.count {
            pages[page].append(id)
        } else {
            pages.append([id])
        }
        setPages(pages)
    }

    func moveToHidden(_ id: String, available: [String]) {
        hiddenWidgets.insert(id)
        setPages(reconciled(available: available))
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let appearance = "opennook.appearance"
        static let accent = "opennook.accent"
        static let glassTint = "opennook.glassTint"
        static let clipboardLimit = "opennook.clipboardLimit"
        static let usageBudget5h = "opennook.usageBudget5h"
        static let usageBudgetWeek = "opennook.usageBudgetWeek"
        static let hiddenWidgets = "opennook.hiddenWidgets"
        static let layout = "opennook.layout"
    }

    init() {
        appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .glass
        accent = AccentChoice(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .pink
        glassTint = defaults.object(forKey: Keys.glassTint) as? Double ?? 0
        clipboardLimit = defaults.object(forKey: Keys.clipboardLimit) as? Int ?? 50
        usageBudget5h = defaults.object(forKey: Keys.usageBudget5h) as? Double ?? 50
        usageBudgetWeek = defaults.object(forKey: Keys.usageBudgetWeek) as? Double ?? 500
        hiddenWidgets = Set(defaults.stringArray(forKey: Keys.hiddenWidgets) ?? [])
        if let data = defaults.data(forKey: Keys.layout),
           let saved = try? JSONDecoder().decode([[String]].self, from: data)
        {
            layout = saved
        } else {
            layout = Settings.defaultLayout
        }
    }
}

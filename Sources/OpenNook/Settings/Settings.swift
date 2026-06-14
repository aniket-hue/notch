import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case glass, solid
    var id: String { rawValue }
    var label: String { self == .glass ? "Glass" : "Solid" }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case pink, blue, green, orange, purple, mono
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pink: return Color(red: 1.0, green: 0.33, blue: 0.62)
        case .blue: return Color(red: 0.36, green: 0.62, blue: 1.0)
        case .green: return Color(red: 0.30, green: 0.86, blue: 0.52)
        case .orange: return Color(red: 1.0, green: 0.55, blue: 0.26)
        case .purple: return Color(red: 0.69, green: 0.45, blue: 1.0)
        case .mono: return Color.white
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
    @Published var hiddenWidgets: Set<String> {
        didSet { defaults.set(Array(hiddenWidgets), forKey: Keys.hiddenWidgets) }
    }

    var accentColor: Color { accent.color }

    func isWidgetEnabled(_ id: String) -> Bool { !hiddenWidgets.contains(id) }
    func setWidget(_ id: String, enabled: Bool) {
        if enabled { hiddenWidgets.remove(id) } else { hiddenWidgets.insert(id) }
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let appearance = "opennook.appearance"
        static let accent = "opennook.accent"
        static let glassTint = "opennook.glassTint"
        static let clipboardLimit = "opennook.clipboardLimit"
        static let hiddenWidgets = "opennook.hiddenWidgets"
    }

    init() {
        appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .glass
        accent = AccentChoice(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .pink
        glassTint = defaults.object(forKey: Keys.glassTint) as? Double ?? 0
        clipboardLimit = defaults.object(forKey: Keys.clipboardLimit) as? Int ?? 50
        hiddenWidgets = Set(defaults.stringArray(forKey: Keys.hiddenWidgets) ?? [])
    }
}

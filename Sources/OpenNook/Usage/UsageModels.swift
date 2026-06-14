import Foundation

enum UsageWindowKind: String {
    case fiveHour
    case week
}

struct UsageWindow: Equatable {
    let kind: UsageWindowKind
    let title: String
    let tokens: Int
    let cost: Double
    let resetsAt: Date?
}

struct UsageSnapshot: Equatable {
    let providerID: String
    let providerName: String
    let windows: [UsageWindow]
    let hasData: Bool
    let updatedAt: Date

    static func empty(id: String = "claude", name: String = "Claude") -> UsageSnapshot {
        UsageSnapshot(providerID: id, providerName: name, windows: [], hasData: false, updatedAt: .distantPast)
    }
}

protocol UsageProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func snapshot() async -> UsageSnapshot
}

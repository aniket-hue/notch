import Foundation

struct DayStat: Equatable {
    let label: String
    let cost: Double
    let isToday: Bool
}

struct ProjectStat: Equatable {
    let name: String
    let cost: Double
    let sessions: Int
}

struct ModelStat: Equatable {
    let key: String
    let cost: Double
}

struct ActivitySnapshot: Equatable {
    let activeTodayHours: Double
    let sessionsWeek: Int
    let costWeek: Double
    let days: [DayStat]
    let projects: [ProjectStat]
    let models: [ModelStat]
    let filesWeek: Int
    let hasData: Bool
    let updatedAt: Date

    static func empty() -> ActivitySnapshot {
        ActivitySnapshot(
            activeTodayHours: 0, sessionsWeek: 0, costWeek: 0,
            days: [], projects: [], models: [], filesWeek: 0,
            hasData: false, updatedAt: .distantPast,
        )
    }
}

protocol UsageProvider {
    var id: String { get }
    var displayName: String { get }
    func snapshot() async -> ActivitySnapshot
}

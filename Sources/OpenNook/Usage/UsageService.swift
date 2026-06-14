import Combine
import Foundation

@MainActor
final class UsageService: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot.empty()
    @Published private(set) var loading = false

    private let provider: UsageProvider
    private var timer: Timer?

    init(provider: UsageProvider = ClaudeUsageProvider()) {
        self.provider = provider
    }

    func start() {
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !loading else { return }
        loading = true
        Task { [provider] in
            let snap = await provider.snapshot()
            self.snapshot = snap
            self.loading = false
        }
    }
}

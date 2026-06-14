import AppKit

struct PullRequest: Identifiable, Equatable {
    enum Kind { case review, mine }
    enum CI { case pass, fail, pending, none }
    enum Review { case approved, changes, pending, none }

    let id: String
    let nodeId: String
    let number: Int
    let title: String
    let repo: String
    let author: String
    let avatarURL: URL?
    let url: URL
    let kind: Kind
    let ci: CI
    let review: Review
    let updatedAt: Date

    var repoShort: String {
        repo.split(separator: "/").last.map(String.init) ?? repo
    }

    static func == (a: PullRequest, b: PullRequest) -> Bool {
        a.id == b.id && a.ci == b.ci && a.review == b.review && a.title == b.title
    }
}

struct GitHubError: Error {
    let message: String
}

@MainActor
final class GitHubService: ObservableObject {
    enum Status: Equatable {
        case needsToken, loading, ready, error(String)
    }

    @Published private(set) var prs: [PullRequest] = []
    @Published private(set) var status: Status = .needsToken
    @Published private(set) var approving: Set<String> = []

    private var timer: Timer?
    private let tokenAccount = "github-token"

    var hasToken: Bool {
        token != nil
    }

    private var token: String? {
        let value = Keychain.get(account: tokenAccount)
        return (value?.isEmpty == false) ? value : nil
    }

    func start() {
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func setToken(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Keychain.delete(account: tokenAccount)
        } else {
            Keychain.set(trimmed, account: tokenAccount)
        }
        prs = []
        refresh()
    }

    func refresh() {
        guard let token else {
            status = .needsToken
            return
        }
        if prs.isEmpty { status = .loading }
        Task { [weak self] in
            let result = await GitHubService.fetch(token: token)
            self?.apply(result)
        }
    }

    func open(_ pr: PullRequest) {
        NSWorkspace.shared.open(pr.url)
    }

    func copyLink(_ pr: PullRequest) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pr.url.absoluteString, forType: .string)
    }

    func approve(_ pr: PullRequest) {
        guard let token, !approving.contains(pr.id) else { return }
        approving.insert(pr.id)
        let nodeId = pr.nodeId
        Task { [weak self] in
            let ok = await GitHubService.runApprove(token: token, nodeId: nodeId)
            await MainActor.run {
                self?.approving.remove(pr.id)
                if ok { self?.refresh() }
            }
        }
    }

    private nonisolated static func runApprove(token: String, nodeId: String) async -> Bool {
        let mutation = "mutation($id: ID!) { addPullRequestReview(input: { pullRequestId: $id, event: APPROVE }) { clientMutationId } }"
        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["query": mutation, "variables": ["id": nodeId]])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200
        else { return false }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["errors"] != nil {
            return false
        }
        return true
    }

    private func apply(_ result: Result<[PullRequest], GitHubError>) {
        switch result {
        case let .success(list):
            prs = list
            status = .ready
        case let .failure(error):
            status = .error(error.message)
        }
    }

    private static let query = """
    fragment PR on PullRequest {
      id number title url isDraft reviewDecision updatedAt
      repository { nameWithOwner }
      author { login avatarUrl }
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
    }
    {
      review: search(query: "is:pr is:open review-requested:@me", type: ISSUE, first: 20) { nodes { ...PR } }
      mine: search(query: "is:pr is:open author:@me", type: ISSUE, first: 20) { nodes { ...PR } }
    }
    """

    private nonisolated static func fetch(token: String) async -> Result<[PullRequest], GitHubError> {
        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["query": query])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 401 { return .failure(GitHubError(message: "Token rejected (401). Check it in Settings.")) }
                if http.statusCode == 403 { return .failure(GitHubError(message: "Rate limited or forbidden (403).")) }
                if !(200 ... 299).contains(http.statusCode) {
                    return .failure(GitHubError(message: "GitHub error \(http.statusCode)."))
                }
            }
            return parse(data)
        } catch {
            return .failure(GitHubError(message: "Couldn't reach GitHub."))
        }
    }

    private nonisolated static func parse(_ data: Data) -> Result<[PullRequest], GitHubError> {
        struct Response: Decodable {
            struct Payload: Decodable {
                let review: Bucket
                let mine: Bucket
            }

            let data: Payload?
            let errors: [GqlError]?
        }
        struct GqlError: Decodable { let message: String }
        struct Bucket: Decodable { let nodes: [Node] }
        struct Node: Decodable {
            let id: String
            let number: Int
            let title: String
            let url: String
            let isDraft: Bool
            let reviewDecision: String?
            let updatedAt: String
            let repository: Repo
            let author: Author?
            let commits: Commits
        }
        struct Repo: Decodable { let nameWithOwner: String }
        struct Author: Decodable {
            let login: String
            let avatarUrl: String?
        }
        struct Commits: Decodable { let nodes: [CommitNode] }
        struct CommitNode: Decodable { let commit: Commit }
        struct Commit: Decodable { let statusCheckRollup: Rollup? }
        struct Rollup: Decodable { let state: String }

        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            return .failure(GitHubError(message: "Couldn't read GitHub response."))
        }
        if let errors = response.errors, let first = errors.first {
            return .failure(GitHubError(message: first.message))
        }
        guard let payload = response.data else {
            return .failure(GitHubError(message: "No data returned."))
        }

        let iso = ISO8601DateFormatter()

        func map(_ node: Node, kind: PullRequest.Kind) -> PullRequest {
            PullRequest(
                id: node.url,
                nodeId: node.id,
                number: node.number,
                title: node.title,
                repo: node.repository.nameWithOwner,
                author: node.author?.login ?? "unknown",
                avatarURL: node.author?.avatarUrl.flatMap(URL.init),
                url: URL(string: node.url) ?? URL(string: "https://github.com")!,
                kind: kind,
                ci: ci(node),
                review: review(node),
                updatedAt: iso.date(from: node.updatedAt) ?? .distantPast,
            )
        }

        func ci(_ node: Node) -> PullRequest.CI {
            switch node.commits.nodes.first?.commit.statusCheckRollup?.state {
            case "SUCCESS": .pass
            case "FAILURE", "ERROR": .fail
            case "PENDING", "EXPECTED": .pending
            default: .none
            }
        }

        func review(_ node: Node) -> PullRequest.Review {
            switch node.reviewDecision {
            case "APPROVED": .approved
            case "CHANGES_REQUESTED": .changes
            case "REVIEW_REQUIRED": .pending
            default: .none
            }
        }

        let review = payload.review.nodes.map { map($0, kind: .review) }
        let mine = payload.mine.nodes.map { map($0, kind: .mine) }
        var seen = Set<String>()
        let merged = (review + mine).filter { seen.insert($0.id).inserted }
        return .success(merged)
    }
}

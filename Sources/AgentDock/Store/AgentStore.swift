import Foundation
import Combine

/// 全 Collector を定期実行してセッション一覧を保持するストア
@MainActor
final class AgentStore: ObservableObject {
    /// この時間更新のない「要対応」は停滞(stale)として扱う
    static let staleThreshold: TimeInterval = 2 * 60 * 60
    private static let pinnedKey = "pinnedSessionIds"

    @Published private(set) var sessions: [AgentSession] = []
    @Published private(set) var pinnedIds: Set<String> =
        Set(UserDefaults.standard.stringArray(forKey: AgentStore.pinnedKey) ?? [])

    /// メニューバーのバッジ件数。停滞したものはピン留め中のみ数える
    var needsAttentionCount: Int {
        sessions.filter {
            $0.status == .needsAttention && (isPinned($0) || !isStale($0))
        }.count
    }

    // MARK: - グルーピング(ピン留め → 要対応 → 実行中 → 停滞中 → アイドル)

    var pinnedSessions: [AgentSession] { sessions.filter { isPinned($0) } }

    var attentionSessions: [AgentSession] {
        sessions.filter { !isPinned($0) && $0.status == .needsAttention && !isStale($0) }
    }

    var runningSessions: [AgentSession] {
        sessions.filter { !isPinned($0) && $0.status == .running }
    }

    /// 長時間放置された要対応
    var staleSessions: [AgentSession] {
        sessions.filter { !isPinned($0) && $0.status == .needsAttention && isStale($0) }
    }

    var idleSessions: [AgentSession] {
        sessions.filter { !isPinned($0) && $0.status == .idle }
    }

    func isPinned(_ session: AgentSession) -> Bool {
        pinnedIds.contains(session.id)
    }

    func isStale(_ session: AgentSession) -> Bool {
        session.status == .needsAttention
            && Date().timeIntervalSince(session.lastActivity) > Self.staleThreshold
    }

    func togglePin(_ session: AgentSession) {
        if pinnedIds.contains(session.id) {
            pinnedIds.remove(session.id)
        } else {
            pinnedIds.insert(session.id)
        }
        UserDefaults.standard.set(Array(pinnedIds), forKey: Self.pinnedKey)
    }

    private let collectors: [Collector] = [
        ClaudeCodeCollector(),
        CodexCollector(),
        VSCodeCollector(),
    ]
    private var timer: Timer?
    private var previousStatuses: [String: AgentStatus] = [:]
    private var hasRefreshedOnce = false

    func start(interval: TimeInterval = 3) {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let collectors = self.collectors
        Task.detached(priority: .utility) {
            let collected = collectors.flatMap { $0.collect() }
            await self.apply(collected)
        }
    }

    private func apply(_ collected: [AgentSession]) {
        // id 重複は先勝ちで除去し、要対応 → 実行中 → アイドル、各グループ内は新しい順に並べる
        var seen = Set<String>()
        let unique = collected.filter { seen.insert($0.id).inserted }
        let sorted = unique.sorted {
            if $0.status != $1.status { return $0.status < $1.status }
            return $0.lastActivity > $1.lastActivity
        }

        // 「要対応」への遷移を通知(起動直後の初回収集ではまとめて鳴らさない)
        if hasRefreshedOnce {
            for session in sorted where session.status == .needsAttention
                && previousStatuses[session.id] != .needsAttention
                && previousStatuses[session.id] != nil {
                Notifier.notify(
                    title: "Agent Dock",
                    body: "\(session.name) (\(session.source.rawValue)) が対応待ちです"
                )
            }
        }

        previousStatuses = Dictionary(
            sorted.map { ($0.id, $0.status) },
            uniquingKeysWith: { first, _ in first }
        )
        hasRefreshedOnce = true
        if sorted != sessions {
            sessions = sorted
        }
    }
}

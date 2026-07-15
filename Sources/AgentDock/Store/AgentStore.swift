import Foundation
import Combine

/// Store that runs all collectors periodically and holds the session list
@MainActor
final class AgentStore: ObservableObject {
    /// A "needs attention" session with no update within this time is treated as stale
    nonisolated static let staleThreshold: TimeInterval = 2 * 60 * 60
    private static let pinnedKey = "pinnedSessionIds"
    private static let customTitlesKey = "customSessionTitles"

    @Published private(set) var sessions: [AgentSession] = []
    @Published private(set) var pinnedIds: Set<String> =
        Set(UserDefaults.standard.stringArray(forKey: AgentStore.pinnedKey) ?? [])
    /// User-defined title overrides (session id → title). Kept in our own
    /// defaults; the agents' session files are never written to.
    @Published private(set) var customTitles: [String: String] =
        (UserDefaults.standard.dictionary(forKey: AgentStore.customTitlesKey) as? [String: String]) ?? [:]

    /// Badge count shown in the menu bar. Stalled sessions only count if pinned.
    var needsAttentionCount: Int {
        sessions.filter {
            $0.status == .needsAttention && (isPinned($0) || !isStale($0))
        }.count
    }

    // MARK: - Grouping (pinned → needs attention → running → stalled → idle)

    var pinnedSessions: [AgentSession] { sessions.filter { isPinned($0) } }

    var attentionSessions: [AgentSession] {
        sessions.filter { !isPinned($0) && $0.status == .needsAttention && !isStale($0) }
    }

    var runningSessions: [AgentSession] {
        sessions.filter { !isPinned($0) && $0.status == .running }
    }

    /// Needs-attention sessions left unattended for a long time
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

    /// Sets (or clears, when nil/empty) the user-defined title of a session
    /// and updates the visible list immediately
    func setCustomTitle(_ title: String?, for session: AgentSession) {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            customTitles[session.id] = trimmed
        } else {
            customTitles.removeValue(forKey: session.id)
        }
        UserDefaults.standard.set(customTitles, forKey: Self.customTitlesKey)
        sessions = applyCustomTitles(to: sessions)
    }

    private func applyCustomTitles(to sessions: [AgentSession]) -> [AgentSession] {
        sessions.map { session in
            var session = session
            session.customTitle = customTitles[session.id]
            return session
        }
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
        // Deduplicate ids keeping the first occurrence, then sort by needs attention → running → idle,
        // most recent first within each group
        var seen = Set<String>()
        let unique = applyCustomTitles(to: collected.filter { seen.insert($0.id).inserted })
        let sorted = unique.sorted {
            if $0.status != $1.status { return $0.status < $1.status }
            return $0.lastActivity > $1.lastActivity
        }

        // Notify on transitions into "needs attention" (skip the batch of notifications on the
        // very first collection right after launch)
        if hasRefreshedOnce {
            for session in sorted where !session.isAutomated
                && session.status == .needsAttention
                && previousStatuses[session.id] != .needsAttention
                && previousStatuses[session.id] != nil {
                Notifier.notify(
                    title: "Agent Dock",
                    body: loc("notification.needsAttention", session.name, session.source.rawValue)
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

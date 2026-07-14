import Foundation

/// Type of tool being monitored
enum AgentSource: String, CaseIterable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case vscode = "VS Code"

    var badgeText: String {
        switch self {
        case .claudeCode: return "CC"
        case .codex: return "CX"
        case .vscode: return "VS"
        }
    }
}

/// Current state of an agent. Ascending rawValue order is display priority (needsAttention first).
enum AgentStatus: Int, Comparable {
    case needsAttention = 0
    case running = 1
    case idle = 2

    static func < (lhs: AgentStatus, rhs: AgentStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .needsAttention: return loc("status.needsAttention")
        case .running: return loc("status.running")
        case .idle: return loc("status.idle")
        }
    }
}

/// A single agent session (= one row in the dashboard)
struct AgentSession: Identifiable, Equatable {
    let id: String
    let source: AgentSource
    let name: String
    let cwd: String
    let status: AgentStatus
    let lastActivity: Date
    /// Kind of entrypoint (claude-vscode / cli / codex-tui, etc). Used to decide which app to bring forward.
    let entrypoint: String?
    /// Excerpt of the agent's latest message (only when available)
    var lastMessage: String? = nil
    /// Session title (recorded by the desktop app, or an excerpt of the first prompt)
    var title: String? = nil
    /// Whether this is a non-interactive / background run (e.g. `codex exec`,
    /// a headless session). Such sessions are nested under their parent and
    /// do not raise notifications.
    var isAutomated: Bool = false

    /// Format message text into a single-line snippet for list display
    static func snippet(of text: String, maxLength: Int = 150) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(flattened.prefix(maxLength))
    }

    /// Display path with the home directory abbreviated to ~
    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if cwd.hasPrefix(home) {
            return "~" + cwd.dropFirst(home.count)
        }
        return cwd
    }
}

import Foundation

/// 監視対象のツール種別
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

/// エージェントの現在状態。rawValue の昇順が表示優先順(要対応が最上位)。
enum AgentStatus: Int, Comparable {
    case needsAttention = 0
    case running = 1
    case idle = 2

    static func < (lhs: AgentStatus, rhs: AgentStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .needsAttention: return "要対応"
        case .running: return "実行中"
        case .idle: return "アイドル"
        }
    }
}

/// 1つのエージェントセッション(= ダッシュボードの1行)
struct AgentSession: Identifiable, Equatable {
    let id: String
    let source: AgentSource
    let name: String
    let cwd: String
    let status: AgentStatus
    let lastActivity: Date
    /// 起動元の種別(claude-vscode / cli / codex-tui など)。復帰先アプリの判定に使う
    let entrypoint: String?
    /// エージェントの最新メッセージの抜粋(取得できる場合のみ)
    var lastMessage: String? = nil
    /// セッションのタイトル(デスクトップアプリの記録、または最初のプロンプトの抜粋)
    var title: String? = nil

    /// メッセージ本文を一覧表示用の1行スニペットに整形する
    static func snippet(of text: String, maxLength: Int = 150) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(flattened.prefix(maxLength))
    }

    /// ホームディレクトリを ~ に短縮した表示用パス
    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if cwd.hasPrefix(home) {
            return "~" + cwd.dropFirst(home.count)
        }
        return cwd
    }
}

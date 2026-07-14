import Foundation

/// Claude デスクトップアプリが保存するセッションタイトルの索引
/// (~/Library/Application Support/Claude/claude-code-sessions/**.json)。
/// VS Code / CLI セッションのタイトルはここには存在しない。
final class ClaudeDesktopTitleIndex {
    static let shared = ClaudeDesktopTitleIndex()

    private let lock = NSLock()
    private var titles: [String: String] = [:]
    private var lastScan: Date = .distantPast
    private static let rescanInterval: TimeInterval = 60

    func title(forCliSessionId sessionId: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        rescanIfNeeded()
        return titles[sessionId]
    }

    private func rescanIfNeeded() {
        guard Date().timeIntervalSince(lastScan) > Self.rescanInterval else { return }
        lastScan = Date()

        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions")
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil
        ) else { return }

        var found: [String: String] = [:]
        for case let file as URL in enumerator where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let cliSessionId = obj["cliSessionId"] as? String,
                  let title = obj["title"] as? String, !title.isEmpty else { continue }
            found[cliSessionId] = title
        }
        titles = found
    }
}

/// タイトルの記録がないセッション向けに、最初のユーザープロンプトの抜粋を
/// 疑似タイトルとして使う。セッションの先頭は変化しないためキャッシュする。
final class FirstPromptCache {
    static let shared = FirstPromptCache()

    private let lock = NSLock()
    private var cache: [String: String?] = [:]
    private static let maxLength = 60

    /// Claude Code トランスクリプト(先頭側の user エントリ)から抽出。
    /// 先頭はコマンド展開・ツール結果で埋まることがあるため広めに読む(結果はキャッシュ)
    func firstPrompt(claudeTranscript url: URL) -> String? {
        cached(url.path) {
            for line in headLines(of: url, maxBytes: 8 * 1024 * 1024) {
                guard let obj = JSONLFile.parse(line),
                      obj["type"] as? String == "user",
                      obj["isMeta"] as? Bool != true,
                      let message = obj["message"] as? [String: Any] else { continue }
                if let text = userText(from: message), isRealPrompt(text) {
                    return AgentSession.snippet(of: text, maxLength: Self.maxLength)
                }
            }
            return nil
        }
    }

    /// Codex ロールアウト(先頭側の user メッセージ)から抽出
    func firstPrompt(codexRollout url: URL) -> String? {
        cached(url.path) {
            for line in headLines(of: url) {
                guard let obj = JSONLFile.parse(line),
                      let payload = obj["payload"] as? [String: Any],
                      payload["type"] as? String == "message",
                      payload["role"] as? String == "user",
                      let content = payload["content"] as? [[String: Any]] else { continue }
                let text = content.compactMap { $0["text"] as? String }.joined(separator: " ")
                if isRealPrompt(text) {
                    return AgentSession.snippet(of: text, maxLength: Self.maxLength)
                }
            }
            return nil
        }
    }

    private func cached(_ key: String, resolve: () -> String?) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[key] {
            return hit
        }
        let value = resolve()
        cache[key] = value
        return value
    }

    private func headLines(of url: URL, maxBytes: Int = 65536) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maxBytes) else { return [] }
        return data.split(separator: UInt8(ascii: "\n"))
            .compactMap { String(data: Data($0), encoding: .utf8) }
    }

    private func userText(from message: [String: Any]) -> String? {
        if let text = message["content"] as? String {
            return text
        }
        if let content = message["content"] as? [[String: Any]] {
            let text = content
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: " ")
            return text.isEmpty ? nil : text
        }
        return nil
    }

    /// システム注入(コマンド展開・Caveat・スキル前文・継続セッションの引き継ぎ文など)を除外する
    private static let systemPrefixes = [
        "<",
        "[",
        "Caveat:",
        "Base directory for this skill",
        "This session is being continued",
    ]

    private func isRealPrompt(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !Self.systemPrefixes.contains { trimmed.hasPrefix($0) }
    }
}

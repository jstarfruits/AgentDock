import Foundation

/// Index of session titles saved by the Claude desktop app
/// (~/Library/Application Support/Claude/claude-code-sessions/**.json).
/// VS Code / CLI session titles do not exist here.
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

/// For sessions without a recorded title, uses an excerpt of the first user prompt
/// as a pseudo-title. Cached because the start of a session never changes.
final class FirstPromptCache {
    static let shared = FirstPromptCache()

    private enum Entry {
        case found(String)
        /// Timestamp when the prompt wasn't found. A file still being written may not
        /// have a prompt yet, so retry after a delay.
        case missing(Date)
    }

    private let lock = NSLock()
    private var cache: [String: Entry] = [:]
    private static let maxLength = 60
    private static let retryInterval: TimeInterval = 120

    /// Extracts from a Claude Code transcript (user entries near the start).
    /// The start can be filled with command expansions or tool results, so this reads a
    /// wide window (the result is cached).
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

    /// Extracts from a Codex rollout (user messages near the start)
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
        switch cache[key] {
        case .found(let value):
            return value
        case .missing(let checkedAt) where Date().timeIntervalSince(checkedAt) < Self.retryInterval:
            return nil
        default:
            let value = resolve()
            cache[key] = value.map(Entry.found) ?? .missing(Date())
            return value
        }
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

    /// Filters out system-injected text (command expansions, caveats, skill preambles,
    /// continued-session handoff text, etc.)
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

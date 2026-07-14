import Foundation

/// Collects Codex session state from ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl.
/// Codex has no live session registry, so this targets rollout files updated
/// within the last 24 hours.
struct CodexCollector: Collector {
    static let activeWindow: TimeInterval = 24 * 60 * 60
    static let runningWindow: TimeInterval = 60
    /// Codex has no way to check process liveness, so sessions older than this are
    /// treated as "idle" rather than "needs attention" even if they finished
    static let attentionWindow: TimeInterval = 2 * 60 * 60

    private var sessionsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions")
    }

    func collect() -> [AgentSession] {
        var sessions: [AgentSession] = []
        for dir in recentDayDirectories() {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
            ) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                guard let mtime = fileModificationDate(file),
                      Date().timeIntervalSince(mtime) < Self.activeWindow,
                      let session = makeSession(from: file, mtime: mtime) else { continue }
                sessions.append(session)
            }
        }
        return sessions
    }

    /// Today's and yesterday's date directories (covers the 24-hour window)
    private func recentDayDirectories() -> [URL] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.timeZone = .current
        return [Date(), Date().addingTimeInterval(-86400)].map {
            sessionsDir.appendingPathComponent(formatter.string(from: $0))
        }
    }

    private func makeSession(from file: URL, mtime: Date) -> AgentSession? {
        guard let metaLine = JSONLFile.firstLine(of: file),
              let meta = JSONLFile.parse(metaLine),
              meta["type"] as? String == "session_meta",
              let payload = meta["payload"] as? [String: Any],
              let sessionId = payload["id"] as? String,
              let cwd = payload["cwd"] as? String else { return nil }

        // Skip internal sub-agent rollouts (e.g. the "guardian" approval agent):
        // their source is like {"subagent": {...}}. They aren't user-facing
        // sessions — their first message is a system prompt and their output is
        // JSON — so they must not appear in the list.
        if let source = payload["source"] as? [String: Any], source["subagent"] != nil {
            return nil
        }

        // `codex exec` (background/headless) runs are non-interactive, so they can
        // never be "waiting for user input". originator "codex_exec" / source "exec"
        // identify them reliably.
        let originator = payload["originator"] as? String
        let isAutomated = originator == "codex_exec" || payload["source"] as? String == "exec"

        var status = status(of: file, mtime: mtime)
        // For an automated run, task_complete just means "done" — never surface it
        // as needs-attention (it would otherwise linger for hours as noise).
        if isAutomated, status == .needsAttention {
            status = .idle
        }

        return AgentSession(
            id: "codex:\(sessionId)",
            source: .codex,
            name: URL(fileURLWithPath: cwd).lastPathComponent,
            cwd: cwd,
            status: status,
            lastActivity: mtime,
            entrypoint: originator,
            lastMessage: latestAssistantText(of: file),
            title: FirstPromptCache.shared.firstPrompt(codexRollout: file),
            isAutomated: isAutomated
        )
    }

    /// Extracts an excerpt of the most recent assistant message, searching from the end
    private func latestAssistantText(of file: URL) -> String? {
        for line in JSONLFile.tailLines(of: file).reversed() {
            guard let obj = JSONLFile.parse(line),
                  let payload = obj["payload"] as? [String: Any] else { continue }
            // task_complete events carry the final message directly
            if obj["type"] as? String == "event_msg",
               let text = payload["last_agent_message"] as? String, !text.isEmpty {
                return AgentSession.snippet(of: text)
            }
            if obj["type"] as? String == "response_item",
               payload["type"] as? String == "message",
               payload["role"] as? String == "assistant",
               let content = payload["content"] as? [[String: Any]] {
                let text = content
                    .compactMap { $0["text"] as? String }
                    .joined(separator: " ")
                if !text.isEmpty {
                    return AgentSession.snippet(of: text)
                }
            }
        }
        return nil
    }

    private func status(of file: URL, mtime: Date) -> AgentStatus {
        if Date().timeIntervalSince(mtime) > Self.attentionWindow {
            return .idle
        }
        // Determine status from the most recent event, searching from the end.
        // task_complete = turn finished (waiting for user input), task_started = running.
        for line in JSONLFile.tailLines(of: file).reversed() {
            guard let obj = JSONLFile.parse(line),
                  let payload = obj["payload"] as? [String: Any] else { continue }
            switch obj["type"] as? String {
            case "event_msg":
                switch payload["type"] as? String {
                case "task_complete":
                    return .needsAttention
                case "task_started":
                    return .running
                default:
                    continue
                }
            case "response_item":
                if payload["type"] as? String == "message" {
                    // If it stopped on an assistant message, waiting for input; if user, running
                    return payload["role"] as? String == "assistant" ? .needsAttention : .running
                }
                continue
            default:
                continue
            }
        }
        if Date().timeIntervalSince(mtime) < Self.runningWindow {
            return .running
        }
        return .idle
    }
}

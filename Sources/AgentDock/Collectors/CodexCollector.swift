import Foundation

/// ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl から Codex セッションの状態を収集する。
/// Codex はライブセッションのレジストリを持たないため、直近24時間に
/// 更新のあったロールアウトファイルを対象とする。
struct CodexCollector: Collector {
    static let activeWindow: TimeInterval = 24 * 60 * 60
    static let runningWindow: TimeInterval = 60
    /// Codex はプロセス生存確認ができないため、この時間より古いセッションは
    /// 完了していても「要対応」ではなく「アイドル」として扱う
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

    /// 今日と昨日の日付ディレクトリ(24時間窓をカバー)
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

        return AgentSession(
            id: "codex:\(sessionId)",
            source: .codex,
            name: URL(fileURLWithPath: cwd).lastPathComponent,
            cwd: cwd,
            status: status(of: file, mtime: mtime),
            lastActivity: mtime,
            entrypoint: payload["originator"] as? String,
            lastMessage: latestAssistantText(of: file),
            title: FirstPromptCache.shared.firstPrompt(codexRollout: file)
        )
    }

    /// 末尾側から直近のアシスタント発言の抜粋を取り出す
    private func latestAssistantText(of file: URL) -> String? {
        for line in JSONLFile.tailLines(of: file).reversed() {
            guard let obj = JSONLFile.parse(line),
                  let payload = obj["payload"] as? [String: Any] else { continue }
            // task_complete イベントは最終メッセージをそのまま持っている
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
        // 末尾から直近のイベントを見て状態を判定する。
        // task_complete = ターン完了(ユーザー入力待ち)、task_started = 実行中。
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
                    // assistant メッセージで止まっていれば入力待ち、user なら実行中
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

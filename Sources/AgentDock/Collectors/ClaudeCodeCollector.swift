import Foundation

/// ~/.claude/sessions/*.json(ライブセッション)と
/// ~/.claude/projects/<slug>/<sessionId>.jsonl(トランスクリプト)から
/// Claude Code セッションの状態を収集する
struct ClaudeCodeCollector: Collector {
    /// 直近この秒数以内にトランスクリプトが更新されていれば「実行中」とみなす
    static let runningWindow: TimeInterval = 60

    private struct SessionFile: Decodable {
        let pid: Int32
        let sessionId: String
        let cwd: String
        let startedAt: Double?
        let name: String?
        let entrypoint: String?
    }

    private var claudeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    func collect() -> [AgentSession] {
        let sessionsDir = claudeDir.appendingPathComponent("sessions")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir, includingPropertiesForKeys: nil
        ) else { return [] }

        var bySessionId: [String: AgentSession] = [:]
        let decoder = JSONDecoder()

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let meta = try? decoder.decode(SessionFile.self, from: data),
                  isProcessAlive(meta.pid) else { continue }

            let startedAt = Date(timeIntervalSince1970: (meta.startedAt ?? 0) / 1000)
            let (status, lastActivity, lastMessage) = transcriptState(sessionId: meta.sessionId, cwd: meta.cwd)
            let title = ClaudeDesktopTitleIndex.shared.title(forCliSessionId: meta.sessionId)
                ?? FirstPromptCache.shared.firstPrompt(claudeTranscript: transcriptURL(sessionId: meta.sessionId, cwd: meta.cwd))
            let session = AgentSession(
                id: "claude:\(meta.sessionId)",
                source: .claudeCode,
                name: meta.name ?? URL(fileURLWithPath: meta.cwd).lastPathComponent,
                cwd: meta.cwd,
                status: status,
                lastActivity: lastActivity ?? startedAt,
                entrypoint: meta.entrypoint,
                lastMessage: lastMessage,
                title: title
            )
            // 同一セッションを指す複数の pid ファイルがある場合は新しい方を残す
            if let existing = bySessionId[meta.sessionId],
               existing.lastActivity >= session.lastActivity { continue }
            bySessionId[meta.sessionId] = session
        }
        return Array(bySessionId.values)
    }

    /// cwd を Claude Code のプロジェクトディレクトリ名に変換(非英数字をすべて "-" に)
    static func projectSlug(for cwd: String) -> String {
        String(cwd.map { ch in
            (ch.isASCII && (ch.isLetter || ch.isNumber)) ? ch : "-"
        })
    }

    private func transcriptURL(sessionId: String, cwd: String) -> URL {
        claudeDir
            .appendingPathComponent("projects")
            .appendingPathComponent(Self.projectSlug(for: cwd))
            .appendingPathComponent("\(sessionId).jsonl")
    }

    private func transcriptState(sessionId: String, cwd: String) -> (AgentStatus, Date?, String?) {
        let transcript = transcriptURL(sessionId: sessionId, cwd: cwd)

        guard let mtime = fileModificationDate(transcript) else {
            return (.idle, nil, nil)
        }

        let lines = JSONLFile.tailLines(of: transcript).reversed()
        let lastMessage = latestAssistantText(in: lines)

        // 末尾から直近の user / assistant エントリを探す
        for line in lines {
            guard let obj = JSONLFile.parse(line),
                  let type = obj["type"] as? String else { continue }
            if type == "assistant" {
                let message = obj["message"] as? [String: Any]
                if message?["stop_reason"] as? String == "end_turn" {
                    // ターンが完了してユーザーの入力待ち
                    return (.needsAttention, mtime, lastMessage)
                }
                break
            }
            if type == "user" { break }
        }

        if Date().timeIntervalSince(mtime) < Self.runningWindow {
            return (.running, mtime, lastMessage)
        }
        return (.idle, mtime, lastMessage)
    }

    /// 末尾側から、テキストを含む直近の assistant メッセージの抜粋を取り出す
    private func latestAssistantText(in reversedLines: ReversedCollection<[String]>) -> String? {
        for line in reversedLines {
            guard let obj = JSONLFile.parse(line),
                  obj["type"] as? String == "assistant",
                  let message = obj["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else { continue }
            let text = content
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: " ")
            if !text.isEmpty {
                return AgentSession.snippet(of: text)
            }
        }
        return nil
    }
}

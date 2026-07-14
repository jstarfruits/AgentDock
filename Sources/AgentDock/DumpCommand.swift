import Foundation

/// `agentdock --dump` : print collection results once without launching the UI (debug tool)
enum DumpCommand {
    static func runIfRequested() {
        if CommandLine.arguments.contains("--ax-debug") {
            WindowRaiser.dumpTree(bundleIds: ["com.microsoft.VSCode"])
            exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--raise"),
           CommandLine.arguments.count > index + 1 {
            let text = CommandLine.arguments[index + 1]
            let result = WindowRaiser.raiseWindow(
                bundleIds: ["com.microsoft.VSCode"], titleContains: text
            )
            print("raiseWindow(\"\(text)\") -> \(result)")
            exit(0)
        }
        runFocusIfRequested()
        guard CommandLine.arguments.contains("--dump") else { return }

        let collectors: [Collector] = [
            ClaudeCodeCollector(),
            CodexCollector(),
            VSCodeCollector(),
        ]
        let sessions = collectors
            .flatMap { $0.collect() }
            .sorted {
                if $0.status != $1.status { return $0.status < $1.status }
                return $0.lastActivity > $1.lastActivity
            }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        for session in sessions {
            let time = formatter.string(from: session.lastActivity)
            let message = session.lastMessage.map { String($0.prefix(40)) } ?? "-"
            let title = session.title.map { String($0.prefix(40)) } ?? "-"
            print("[\(session.status.label)] \(session.source.rawValue) | \(session.name) | \(title) | \(session.displayPath) | \(time) | \(session.entrypoint ?? "-") | \(message)")
        }
        let now = Date()
        let badge = sessions.filter {
            !$0.isAutomated && $0.status == .needsAttention
                && now.timeIntervalSince($0.lastActivity) < AgentStore.staleThreshold
        }
        print("total: \(sessions.count) sessions")
        print("menu-bar badge (needs-attention within 2h, excl. automated): \(badge.count) -> \(badge.map(\.name).joined(separator: ", "))")
        exit(0)
    }

    /// `agentdock --focus <path>` : try the focus/raise behavior without the UI (debug tool)
    private static func runFocusIfRequested() {
        guard let index = CommandLine.arguments.firstIndex(of: "--focus"),
              CommandLine.arguments.count > index + 1 else { return }
        let path = CommandLine.arguments[index + 1]
        print("accessibility permission: \(WindowRaiser.ensurePermission() ? "granted" : "not granted (app activation only)")")
        FocusAction.focus(AgentSession(
            id: "debug",
            source: .claudeCode,
            name: URL(fileURLWithPath: path).lastPathComponent,
            cwd: path,
            status: .idle,
            lastActivity: Date(),
            entrypoint: "claude-vscode"
        ))
        exit(0)
    }
}

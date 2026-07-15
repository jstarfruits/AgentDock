import Foundation

/// Returns a fixed set of fake sessions instead of reading real local data.
/// Used only when launched with `--demo`, e.g. for taking screenshots without
/// exposing real project names or message content.
struct DemoCollector: Collector {
    func collect() -> [AgentSession] {
        let now = Date()
        func minutesAgo(_ n: Double) -> Date { now.addingTimeInterval(-n * 60) }
        func hoursAgo(_ n: Double) -> Date { now.addingTimeInterval(-n * 3600) }
        // Build under the real home directory so AgentSession.displayPath collapses
        // it to "~/Projects/…" instead of showing a literal path.
        func projectPath(_ name: String) -> String {
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Projects/\(name)").path
        }

        return [
            AgentSession(
                id: "demo:1", source: .claudeCode, name: "storefront-redesign",
                cwd: projectPath("storefront-redesign"),
                status: .needsAttention, lastActivity: minutesAgo(2),
                entrypoint: "claude-vscode",
                lastMessage: "Checkout flow now handles partial refunds. Ready for review — want me to open a PR?",
                title: "Refactor checkout refund handling"
            ),
            AgentSession(
                id: "demo:2", source: .codex, name: "onboarding-flow",
                cwd: projectPath("onboarding-flow"),
                status: .running, lastActivity: minutesAgo(1),
                entrypoint: "Codex Desktop",
                lastMessage: "Running the updated signup form through the accessibility checker…",
                title: "Add social sign-in buttons"
            ),
            AgentSession(
                id: "demo:3", source: .vscode, name: "internal-dashboard",
                cwd: projectPath("internal-dashboard"),
                status: .idle, lastActivity: minutesAgo(4),
                entrypoint: "vscode"
            ),
            AgentSession(
                id: "demo:4", source: .claudeCode, name: "mobile-client",
                cwd: projectPath("mobile-client"),
                status: .needsAttention, lastActivity: hoursAgo(1),
                entrypoint: "claude-desktop",
                lastMessage: "Migrated the push-notification token refresh to the new API. Tests are green.",
                title: "Push notification token refresh"
            ),
            AgentSession(
                id: "demo:5", source: .codex, name: "billing-service",
                cwd: projectPath("billing-service"),
                status: .idle, lastActivity: minutesAgo(15),
                entrypoint: "codex_exec",
                lastMessage: "Generated the monthly invoice PDFs and uploaded them to the reports bucket.",
                title: "Nightly invoice generation job",
                isAutomated: true
            ),
            AgentSession(
                id: "demo:6", source: .claudeCode, name: "docs-site",
                cwd: projectPath("docs-site"),
                status: .needsAttention, lastActivity: hoursAgo(5),
                entrypoint: "claude-vscode",
                lastMessage: "Rebuilt the search index and fixed the broken anchor links in the API reference.",
                title: "Fix docs search + broken anchors"
            ),
            AgentSession(
                id: "demo:7", source: .vscode, name: "marketing-site",
                cwd: projectPath("marketing-site"),
                status: .idle, lastActivity: hoursAgo(6),
                entrypoint: "vscode"
            ),
            AgentSession(
                id: "demo:8", source: .claudeCode, name: "data-pipeline",
                cwd: projectPath("data-pipeline"),
                status: .idle, lastActivity: hoursAgo(9),
                entrypoint: "claude-vscode"
            ),
        ]
    }
}

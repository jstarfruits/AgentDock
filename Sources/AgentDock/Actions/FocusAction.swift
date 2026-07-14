import AppKit

/// Returns to a session's workspace with a single click
enum FocusAction {
    static func focus(_ session: AgentSession) {
        switch session.source {
        case .vscode:
            openInVSCode(session.cwd)
        case .claudeCode:
            // Choose which app to bring forward based on where it's running
            // (inside VS Code / Claude desktop / a terminal)
            if session.entrypoint?.contains("vscode") == true {
                openInVSCode(session.cwd)
            } else if session.entrypoint?.contains("claude-desktop") == true {
                activateClaudeDesktop(session)
            } else {
                // Terminal-based Claude Code (cli): raise the matching window,
                // else fall back to a running terminal app.
                if !activateTerminal(cwd: session.cwd) {
                    activateApp(bundleIds: terminalBundleIds)
                }
            }
        case .codex:
            // Codex runs have no reliable window to return to — a `codex exec`
            // background task was never attached to a terminal at all. Prefer a
            // terminal window whose title matches the cwd, otherwise fall back to
            // the project's VS Code window. Never raise an unrelated terminal.
            if !activateTerminal(cwd: session.cwd) {
                openInVSCode(session.cwd)
            }
        }
    }

    /// Bundle ids for VS Code-family editors (including Insiders / VSCodium / Cursor)
    static let vscodeBundleIds = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.vscodium",
        "com.todesktop.230313mzl4w4u92", // Cursor
    ]

    /// Only raises an existing window; never opens a new one.
    /// 1. If accessibility permission is granted, AXRaise the window whose title contains the folder name
    /// 2. If not granted, show the permission dialog and just activate the app
    /// 3. If no matching window is found (folder isn't open), also fall back to activating the app
    private static func openInVSCode(_ path: String) {
        let folderName = URL(fileURLWithPath: path).lastPathComponent
        if WindowRaiser.raiseWindow(bundleIds: vscodeBundleIds, titleContains: folderName) {
            return
        }
        WindowRaiser.ensurePermission(prompt: true)
        activateApp(bundleIds: vscodeBundleIds)
    }

    private static func activateApp(bundleIds: [String]) {
        for bundleId in bundleIds {
            if let app = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleId).first {
                app.activate()
                return
            }
        }
    }

    static let claudeDesktopBundleIds = ["com.anthropic.claudefordesktop"]

    /// Returns to a session in the Claude desktop app.
    /// Raises the window matching the session title if one exists, otherwise just activates the app.
    private static func activateClaudeDesktop(_ session: AgentSession) {
        if let title = session.title,
           WindowRaiser.raiseWindow(bundleIds: claudeDesktopBundleIds, titleContains: title) {
            return
        }
        activateApp(bundleIds: claudeDesktopBundleIds)
    }

    static let terminalBundleIds = [
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
        "com.apple.Terminal",
    ]

    /// Raises the terminal window whose title contains the cwd's folder name.
    /// Returns whether such a window was found. Never opens a new terminal or
    /// raises an unrelated one — the caller decides the fallback.
    @discardableResult
    private static func activateTerminal(cwd: String) -> Bool {
        let folderName = URL(fileURLWithPath: cwd).lastPathComponent
        return WindowRaiser.raiseWindow(bundleIds: terminalBundleIds, titleContains: folderName)
    }
}

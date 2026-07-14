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
                activateTerminal(cwd: session.cwd)
            }
        case .codex:
            if session.entrypoint?.contains("vscode") == true {
                openInVSCode(session.cwd)
            } else {
                activateTerminal(cwd: session.cwd)
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

    /// For terminals, raise the window whose title contains the cwd's folder name;
    /// if none is found, activate a running terminal app instead (best effort)
    private static func activateTerminal(cwd: String) {
        let folderName = URL(fileURLWithPath: cwd).lastPathComponent
        if WindowRaiser.raiseWindow(bundleIds: terminalBundleIds, titleContains: folderName) {
            return
        }
        activateApp(bundleIds: terminalBundleIds)
    }
}

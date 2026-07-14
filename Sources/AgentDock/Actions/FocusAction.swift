import AppKit

/// セッションの作業場所へワンクリックで復帰する
enum FocusAction {
    static func focus(_ session: AgentSession) {
        switch session.source {
        case .vscode:
            openInVSCode(session.cwd)
        case .claudeCode:
            // 実行場所(VS Code内 / Claudeデスクトップ / ターミナル)ごとに前面化先を変える
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

    /// VS Code 系エディタの bundle id(Insiders / VSCodium / Cursor を含む)
    static let vscodeBundleIds = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.vscodium",
        "com.todesktop.230313mzl4w4u92", // Cursor
    ]

    /// 既存ウインドウの前面化のみを行い、新しいウインドウは開かない。
    /// 1. アクセシビリティ権限があれば、フォルダ名をタイトルに含むウインドウを AXRaise
    /// 2. 権限が無ければ許可ダイアログを出しつつ、アプリの前面化だけ行う
    /// 3. ウインドウが見つからない(フォルダを開いていない)場合もアプリの前面化に留める
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

    /// Claude デスクトップアプリのセッションへ復帰する。
    /// セッションタイトルと一致するウインドウがあればそれを、なければアプリを前面化する
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

    /// ターミナルはウインドウタイトルに cwd のフォルダ名が含まれていればそれを前面化し、
    /// 見つからなければ実行中のターミナルアプリを前面化する(ベストエフォート)
    private static func activateTerminal(cwd: String) {
        let folderName = URL(fileURLWithPath: cwd).lastPathComponent
        if WindowRaiser.raiseWindow(bundleIds: terminalBundleIds, titleContains: folderName) {
            return
        }
        activateApp(bundleIds: terminalBundleIds)
    }
}

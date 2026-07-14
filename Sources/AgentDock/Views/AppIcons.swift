import AppKit

/// セッションが実際に動いているアプリのアイコンを NSWorkspace から取得する。
/// アイコン画像をリポジトリに含めないための仕組み(見つからなければ nil)。
@MainActor
enum AppIcons {
    private static var cache: [String: NSImage?] = [:]

    /// セッションの実行場所(ホストアプリ)のアイコンを返す。
    /// VS Code 内 → VS Code、Claude デスクトップ → Claude、CLI/TUI → ターミナルアプリ。
    static func icon(for session: AgentSession) -> NSImage? {
        let key = hostKey(for: session)
        return cached(key: key) {
            switch key {
            case "vscode":
                return appIcon(bundleIds: FocusAction.vscodeBundleIds)
            case "claude":
                return appIcon(bundleIds: FocusAction.claudeDesktopBundleIds)
            default:
                return terminalIcon()
            }
        }
    }

    /// 標準メニュー項目用の16ptアイコン
    static func menuIcon(for session: AgentSession) -> NSImage? {
        let key = "menu-\(hostKey(for: session))"
        return cached(key: key) {
            guard let base = icon(for: session),
                  let resized = base.copy() as? NSImage else { return nil }
            resized.size = NSSize(width: 16, height: 16)
            return resized
        }
    }

    private static func hostKey(for session: AgentSession) -> String {
        if session.source == .vscode || session.entrypoint?.contains("vscode") == true {
            return "vscode"
        }
        if session.entrypoint?.contains("claude-desktop") == true {
            return "claude"
        }
        return "terminal"
    }

    private static func cached(key: String, resolve: () -> NSImage?) -> NSImage? {
        if let hit = cache[key] {
            return hit
        }
        let icon = resolve()
        cache[key] = icon
        return icon
    }

    /// 起動中のターミナルアプリを優先し、無ければインストール済みのものを探す
    private static func terminalIcon() -> NSImage? {
        for bundleId in FocusAction.terminalBundleIds {
            if let app = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleId).first,
               let url = app.bundleURL {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        return appIcon(bundleIds: FocusAction.terminalBundleIds)
    }

    private static func appIcon(bundleIds: [String]) -> NSImage? {
        for bundleId in bundleIds {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        return nil
    }
}

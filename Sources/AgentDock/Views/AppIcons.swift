import AppKit

/// Fetches the icon of the app a session is actually running in, via NSWorkspace.
/// This keeps icon images out of the repository (returns nil if not found).
@MainActor
enum AppIcons {
    private static var cache: [String: NSImage?] = [:]

    /// Returns the icon of the session's host app.
    /// Inside VS Code → VS Code, Claude desktop → Claude, CLI/TUI → the terminal app.
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

    /// 16pt icon for standard menu items
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

    /// Prefers a running terminal app; falls back to an installed one if none is running
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

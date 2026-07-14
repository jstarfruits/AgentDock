import AppKit
import UserNotifications

/// macOS 通知。
/// .app バンドルとして実行されている場合は UNUserNotificationCenter を使う
/// (通知クリックで Agent Dock が前面化する)。
/// `swift run` などバンドル無しの開発実行では UNUserNotificationCenter が
/// 使えないため osascript にフォールバックする(この場合クリック先は
/// スクリプトエディタになってしまうが避けられない)。
enum Notifier {
    /// .app バンドルとして起動しているか
    static var isBundledApp: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    /// 起動時に一度呼ぶ。バンドル実行時のみ通知権限を要求する
    static func setUp() {
        guard isBundledApp else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(title: String, body: String) {
        if isBundledApp {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        } else {
            let script = "display notification \"\(escape(body))\" with title \"\(escape(title))\" sound name \"Glass\""
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

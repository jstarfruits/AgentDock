import AppKit
import UserNotifications

/// macOS notifications.
/// When running as a .app bundle, uses UNUserNotificationCenter
/// (clicking a notification brings Agent Dock to the front).
/// UNUserNotificationCenter isn't available for unbundled development runs like
/// `swift run`, so this falls back to osascript in that case (clicking the
/// notification then opens Script Editor instead, which is unavoidable).
enum Notifier {
    /// Whether running as a .app bundle
    static var isBundledApp: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    /// Call once at launch. Only requests notification permission when running as a bundle.
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

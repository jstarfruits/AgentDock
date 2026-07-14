import SwiftUI
import ServiceManagement

/// ログイン項目(自動起動)の登録状態。.app バンドル実行時のみ利用できる
@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 登録失敗時は現状ステータスに合わせて表示を戻す
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

/// メニューバーの標準メニュー(NSMenuスタイル)。
/// 項目クリックで該当セッションへ復帰。停滞中・アイドルはサブメニューに畳む。
struct MenuContentView: View {
    @ObservedObject var store: AgentStore
    @ObservedObject var panelState: PanelState
    @AppStorage("showSessionTitles") private var showTitles = true
    @AppStorage(DisplayScale.textKey) private var textSize = DisplayScale.defaultValue
    @AppStorage(DisplayScale.iconKey) private var iconSize = DisplayScale.defaultValue
    @StateObject private var loginItem = LoginItem()

    var body: some View {
        if store.sessions.isEmpty {
            Text("監視中のエージェントはありません")
        }
        namedSection("ピン留め", store.pinnedSessions)
        namedSection("要対応", store.attentionSessions)
        namedSection("実行中", store.runningSessions)
        if !store.staleSessions.isEmpty {
            Menu("停滞中 (\(store.staleSessions.count))") {
                sessionItems(store.staleSessions)
            }
        }
        if !store.idleSessions.isEmpty {
            Menu("アイドル (\(store.idleSessions.count))") {
                sessionItems(store.idleSessions)
            }
        }

        Divider()

        Toggle("セッションタイトルを表示", isOn: $showTitles)
        Picker("文字サイズ", selection: $textSize) {
            Text("小").tag("small")
            Text("中").tag("medium")
            Text("大").tag("large")
        }
        Picker("アイコンサイズ", selection: $iconSize) {
            Text("小").tag("small")
            Text("中").tag("medium")
            Text("大").tag("large")
        }
        if Notifier.isBundledApp {
            Toggle("ログイン時に起動", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.set($0) }
            ))
        }
        Button(panelState.isVisible ? "パネルを隠す" : "パネルを表示") {
            panelState.toggle()
        }

        Divider()

        Button("Agent Dock を終了") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    @ViewBuilder
    private func namedSection(_ title: String, _ sessions: [AgentSession]) -> some View {
        if !sessions.isEmpty {
            Section("\(title) (\(sessions.count))") {
                sessionItems(sessions)
            }
        }
    }

    @ViewBuilder
    private func sessionItems(_ sessions: [AgentSession]) -> some View {
        ForEach(sessions) { session in
            Button {
                FocusAction.focus(session)
            } label: {
                if let icon = AppIcons.menuIcon(for: session) {
                    Label {
                        Text(itemTitle(session))
                    } icon: {
                        Image(nsImage: icon)
                    }
                    .labelStyle(.titleAndIcon)
                } else {
                    Text(itemTitle(session))
                }
            }
        }
    }

    private func itemTitle(_ session: AgentSession) -> String {
        let name = showTitles ? (session.title ?? session.name) : session.name
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let time = formatter.localizedString(for: session.lastActivity, relativeTo: Date())
        return "\(name) — \(time)"
    }
}

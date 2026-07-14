import SwiftUI

/// メニューバーの標準メニュー(NSMenuスタイル)。
/// 項目クリックで該当セッションへ復帰。停滞中・アイドルはサブメニューに畳む。
struct MenuContentView: View {
    @ObservedObject var store: AgentStore
    @ObservedObject var panelState: PanelState
    @AppStorage("showSessionTitles") private var showTitles = true

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

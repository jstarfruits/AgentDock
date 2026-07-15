import SwiftUI
import ServiceManagement

/// Login item (auto-launch) registration state. Only usable when running as a .app bundle.
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
            // Registration failed; fall back to reflecting the current status
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

/// Standard menu bar menu (NSMenu style).
/// Clicking an item returns to the corresponding session. Stalled/idle sessions collapse into submenus.
struct MenuContentView: View {
    @ObservedObject var store: AgentStore
    @ObservedObject var panelState: PanelState
    @AppStorage("showSessionTitles") private var showTitles = true
    @AppStorage(DisplayScale.textKey) private var textSize = DisplayScale.defaultValue
    @AppStorage(DisplayScale.iconKey) private var iconSize = DisplayScale.defaultValue
    @StateObject private var loginItem = LoginItem()

    var body: some View {
        if store.sessions.isEmpty {
            Text(loc("menu.noAgents"))
        }
        namedSection(loc("section.pinned"), store.pinnedSessions)
        namedSection(loc("status.needsAttention"), store.attentionSessions)
        namedSection(loc("status.running"), store.runningSessions)
        if !store.staleSessions.isEmpty {
            Menu("\(loc("section.stalled")) (\(store.staleSessions.count))") {
                sessionItems(store.staleSessions)
            }
        }
        if !store.idleSessions.isEmpty {
            Menu("\(loc("status.idle")) (\(store.idleSessions.count))") {
                sessionItems(store.idleSessions)
            }
        }

        Divider()

        Toggle(loc("menu.showTitles"), isOn: $showTitles)
        Picker(loc("menu.textSize"), selection: $textSize) {
            Text(loc("size.small")).tag("small")
            Text(loc("size.medium")).tag("medium")
            Text(loc("size.large")).tag("large")
        }
        Picker(loc("menu.iconSize"), selection: $iconSize) {
            Text(loc("size.small")).tag("small")
            Text(loc("size.medium")).tag("medium")
            Text(loc("size.large")).tag("large")
        }
        if Notifier.isBundledApp {
            Toggle(loc("menu.launchAtLogin"), isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.set($0) }
            ))
        }
        Button(panelState.isVisible ? loc("menu.hidePanel") : loc("menu.showPanel")) {
            panelState.toggle()
        }

        Divider()

        Button(loc("menu.quit")) {
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
        let name = showTitles ? (session.displayTitle ?? session.name) : session.name
        return "\(name) — \(RelativeTime.string(for: session.lastActivity))"
    }
}

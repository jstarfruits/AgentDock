import AppKit
import SwiftUI

@main
struct AgentDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        DumpCommand.runIfRequested()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: delegate.store, panelState: delegate.panelState)
        } label: {
            MenuBarLabel(store: delegate.store)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    /// `--demo` shows fixed fake sessions instead of reading real local data
    /// (used for taking screenshots without exposing real project data).
    private static var isDemo: Bool { CommandLine.arguments.contains("--demo") }

    let store = AgentStore(collectors: AppDelegate.isDemo ? [DemoCollector()] : [
        ClaudeCodeCollector(), CodexCollector(), VSCodeCollector(),
    ])
    let panelState = PanelState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a menu bar resident app without showing a Dock icon
        NSApp.setActivationPolicy(.accessory)
        Notifier.setUp()
        store.start()
        panelState.attach(store: store)
        if Self.isDemo {
            // Pin one session so the screenshot also shows the pinned section
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                if let session = store.sessions.first(where: { $0.id == "demo:1" }) {
                    store.togglePin(session)
                }
            }
        }
    }
}

/// Icon shown in the menu bar. Highlighted with a count when sessions need attention.
struct MenuBarLabel: View {
    @ObservedObject var store: AgentStore

    var body: some View {
        let count = store.needsAttentionCount
        if count > 0 {
            Image(systemName: "bell.badge.fill")
            Text("\(count)")
        } else {
            Image(systemName: "rectangle.3.group")
        }
    }
}

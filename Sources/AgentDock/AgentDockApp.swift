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
    let store = AgentStore()
    let panelState = PanelState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a menu bar resident app without showing a Dock icon
        NSApp.setActivationPolicy(.accessory)
        Notifier.setUp()
        store.start()
        panelState.attach(store: store)
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

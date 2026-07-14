import AppKit
import SwiftUI

/// Visibility state of the always-on-top panel (referenced by both the menu and the panel)
@MainActor
final class PanelState: ObservableObject {
    @Published private(set) var isVisible: Bool

    private static let visibleKey = "panelVisible"
    private var controller: FloatingPanelController?

    init() {
        isVisible = UserDefaults.standard.object(forKey: Self.visibleKey) as? Bool ?? true
    }

    func attach(store: AgentStore) {
        controller = FloatingPanelController(store: store, panelState: self)
        if isVisible {
            controller?.show()
        }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        isVisible = true
        UserDefaults.standard.set(true, forKey: Self.visibleKey)
        controller?.show()
    }

    func hide() {
        isVisible = false
        UserDefaults.standard.set(false, forKey: Self.visibleKey)
        controller?.hide()
    }
}

/// An always-on-top, non-activating panel. Clicking it never steals focus from other apps,
/// and it stays visible over full-screen apps and across all Spaces.
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private weak var panelState: PanelState?

    init(store: AgentStore, panelState: PanelState) {
        self.panelState = panelState
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 360),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        // The close button is drawn on the SwiftUI side in traffic-light style
        // (the standard button's position doesn't line up on a transparent panel)
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false

        // Layout is driven by the window size to support resizing
        // (size and position are persisted via setFrameAutosaveName)
        panel.minSize = NSSize(width: 240, height: 160)
        let hosting = NSHostingView(
            rootView: FloatingPanelView(store: store, panelState: panelState)
        )
        panel.contentView = hosting

        panel.setFrameAutosaveName("AgentDockFloatingPanel")
        if panel.frame.origin == .zero, let screen = NSScreen.main {
            // Position at the top-right of the screen on first launch
            let frame = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(
                x: frame.maxX - panel.frame.width - 16,
                y: frame.maxY - 16
            ))
        }
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Treat the standard close button as "hide" and reflect it in the persisted visibility state
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        panelState?.hide()
        return false
    }
}

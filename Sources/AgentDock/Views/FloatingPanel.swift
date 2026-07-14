import AppKit
import SwiftUI

/// 常時最前面パネルの表示状態(メニューとパネル双方から参照する)
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

/// 常時最前面・非アクティブ化パネル。クリックしても他アプリのフォーカスを奪わず、
/// 全画面アプリの上やすべての Space でも表示される。
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
        // 閉じるボタンは SwiftUI 側で信号機風に描画する(透明パネルでは標準ボタンの位置が合わない)
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

        // リサイズ可能にするため、ウインドウサイズ主導でレイアウトする
        // (サイズと位置は setFrameAutosaveName で永続化される)
        panel.minSize = NSSize(width: 240, height: 160)
        let hosting = NSHostingView(
            rootView: FloatingPanelView(store: store, panelState: panelState)
        )
        panel.contentView = hosting

        panel.setFrameAutosaveName("AgentDockFloatingPanel")
        if panel.frame.origin == .zero, let screen = NSScreen.main {
            // 初回起動時は画面右上に配置
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

    /// 標準の閉じるボタンは「非表示」として扱い、表示状態の記憶に反映する
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        panelState?.hide()
        return false
    }
}

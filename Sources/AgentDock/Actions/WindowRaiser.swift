import AppKit
import ApplicationServices

/// アクセシビリティAPIで既存ウインドウ・タブをタイトル一致で前面化する。
/// 新しいウインドウは一切開かない。
enum WindowRaiser {
    /// アクセシビリティ権限の有無。prompt = true なら無い場合にシステムの許可ダイアログを出す
    @discardableResult
    static func ensurePermission(prompt: Bool = false) -> Bool {
        if !prompt {
            return AXIsProcessTrusted()
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// 指定 bundle id 群のアプリから、タイトルに `titleContains` を含むウインドウ
    /// またはネイティブタブを探して前面化する
    @discardableResult
    static func raiseWindow(bundleIds: [String], titleContains: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        for app in NSWorkspace.shared.runningApplications {
            guard let bundleId = app.bundleIdentifier, bundleIds.contains(bundleId) else { continue }
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = elements(of: axApp, attribute: kAXWindowsAttribute) else { continue }

            // 1. ウインドウタイトルの一致(通常ウインドウ、および前面タブ)
            for window in windows where matches(window, titleContains) {
                raise(window: window, app: app)
                return true
            }
            // 2. ウィンドウメニューから選択(ネイティブタブ統合でも確実に切り替わる)
            if raiseViaWindowMenu(axApp: axApp, app: app, titleContains: titleContains) {
                return true
            }
            // 3. タブバー(AXTabGroup)のタブを直接押す(最終手段)
            for window in windows {
                if pressTab(in: window, titleContains: titleContains) {
                    raise(window: window, app: app)
                    return true
                }
            }
        }
        return false
    }

    /// アプリの「ウィンドウ」メニュー末尾に並ぶウインドウ/タブ一覧から
    /// タイトル一致する項目を選択する。ネイティブタブの切り替えにも効く。
    private static func raiseViaWindowMenu(
        axApp: AXUIElement, app: NSRunningApplication, titleContains: String
    ) -> Bool {
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBarValue = menuBarRef, CFGetTypeID(menuBarValue) == AXUIElementGetTypeID() else {
            return false
        }
        let menuBar = menuBarValue as! AXUIElement
        guard let menus = elements(of: menuBar, attribute: kAXChildrenAttribute) else { return false }

        // ウィンドウメニューはメニューバーの後方にあるため逆順に探す
        for menuBarItem in menus.reversed() {
            guard let submenus = elements(of: menuBarItem, attribute: kAXChildrenAttribute) else { continue }
            for submenu in submenus {
                guard let items = elements(of: submenu, attribute: kAXChildrenAttribute) else { continue }
                // ウインドウ一覧はメニューの末尾に並ぶので逆順に探す
                for item in items.reversed() where matches(item, titleContains) {
                    if AXUIElementPerformAction(item, kAXPressAction as CFString) == .success {
                        app.activate()
                        return true
                    }
                }
            }
        }
        return false
    }

    private static func raise(window: AXUIElement, app: NSRunningApplication) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        app.activate()
    }

    private static func matches(_ element: AXUIElement, _ text: String) -> Bool {
        if let title = string(of: element, attribute: kAXTitleAttribute),
           title.localizedCaseInsensitiveContains(text) {
            return true
        }
        if let description = string(of: element, attribute: kAXDescriptionAttribute),
           description.localizedCaseInsensitiveContains(text) {
            return true
        }
        return false
    }

    /// ウインドウ内のタブバー(AXTabGroup)から一致するタブを探して選択する。
    /// Electron 系はアクセシビリティツリーが巨大なため、探索は浅い階層に限定し
    /// Web コンテンツ(AXWebArea)には入らない。
    private static func pressTab(in window: AXUIElement, titleContains: String) -> Bool {
        var queue: [(element: AXUIElement, depth: Int)] = [(window, 0)]
        while !queue.isEmpty {
            let (element, depth) = queue.removeFirst()
            guard let children = elements(of: element, attribute: kAXChildrenAttribute) else { continue }
            for child in children {
                let role = string(of: child, attribute: kAXRoleAttribute)
                switch role {
                case "AXTabGroup":
                    if pressMatchingTab(in: child, titleContains: titleContains) {
                        return true
                    }
                case "AXWebArea", "AXScrollArea":
                    continue
                default:
                    if depth < 4 {
                        queue.append((child, depth + 1))
                    }
                }
            }
        }
        return false
    }

    private static func pressMatchingTab(in tabGroup: AXUIElement, titleContains: String) -> Bool {
        guard let tabs = elements(of: tabGroup, attribute: kAXChildrenAttribute) else { return false }
        for tab in tabs {
            let role = string(of: tab, attribute: kAXRoleAttribute)
            guard role == "AXRadioButton" || role == "AXTab" else { continue }
            if matches(tab, titleContains) {
                return AXUIElementPerformAction(tab, kAXPressAction as CFString) == .success
            }
        }
        return false
    }

    // MARK: - デバッグ

    /// AX ツリーの浅い階層を出力する(構造調査用)
    static func dumpTree(bundleIds: [String], maxDepth: Int = 3) {
        guard AXIsProcessTrusted() else {
            print("アクセシビリティ権限がありません")
            return
        }
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleId = app.bundleIdentifier, bundleIds.contains(bundleId) else { continue }
            print("=== \(bundleId) (pid \(app.processIdentifier)) ===")
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = elements(of: axApp, attribute: kAXWindowsAttribute) else {
                print("  (AXWindows 取得失敗)")
                continue
            }
            for (index, window) in windows.enumerated() {
                print("window[\(index)]")
                dump(element: window, depth: 1, maxDepth: maxDepth)
            }
        }
    }

    private static func dump(element: AXUIElement, depth: Int, maxDepth: Int) {
        let indent = String(repeating: "  ", count: depth)
        let role = string(of: element, attribute: kAXRoleAttribute) ?? "?"
        let title = string(of: element, attribute: kAXTitleAttribute) ?? ""
        let description = string(of: element, attribute: kAXDescriptionAttribute) ?? ""
        print("\(indent)\(role) title=\"\(title)\" desc=\"\(description)\"")
        guard depth < maxDepth, role != "AXWebArea",
              let children = elements(of: element, attribute: kAXChildrenAttribute) else { return }
        for child in children {
            dump(element: child, depth: depth + 1, maxDepth: maxDepth)
        }
    }

    // MARK: - AX ヘルパー

    private static func elements(of element: AXUIElement, attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? [AXUIElement]
    }

    private static func string(of element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }
}

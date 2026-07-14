import AppKit
import ApplicationServices

/// Uses the accessibility API to raise existing windows/tabs by title match.
/// Never opens any new window.
enum WindowRaiser {
    /// Whether accessibility permission is granted. If prompt = true and it isn't,
    /// shows the system permission dialog.
    @discardableResult
    static func ensurePermission(prompt: Bool = false) -> Bool {
        if !prompt {
            return AXIsProcessTrusted()
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Among apps with the given bundle ids, finds a window or native tab whose title
    /// contains `titleContains` and raises it.
    @discardableResult
    static func raiseWindow(bundleIds: [String], titleContains: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        for app in NSWorkspace.shared.runningApplications {
            guard let bundleId = app.bundleIdentifier, bundleIds.contains(bundleId) else { continue }
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = elements(of: axApp, attribute: kAXWindowsAttribute) else { continue }

            // 1. Match on window title (regular windows, and the frontmost tab)
            for window in windows where matches(window, titleContains) {
                raise(window: window, app: app)
                return true
            }
            // 2. Select from the Window menu (reliably switches even with native tabs merged)
            if raiseViaWindowMenu(axApp: axApp, app: app, titleContains: titleContains) {
                return true
            }
            // 3. Press the tab directly in the tab bar (AXTabGroup) (last resort)
            for window in windows {
                if pressTab(in: window, titleContains: titleContains) {
                    raise(window: window, app: app)
                    return true
                }
            }
        }
        return false
    }

    /// Selects the item matching the title from the window/tab list at the end of the
    /// app's "Window" menu. This also works for switching native tabs.
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

        // The Window menu is near the end of the menu bar, so search in reverse
        for menuBarItem in menus.reversed() {
            guard let submenus = elements(of: menuBarItem, attribute: kAXChildrenAttribute) else { continue }
            for submenu in submenus {
                guard let items = elements(of: submenu, attribute: kAXChildrenAttribute) else { continue }
                // The window list is at the end of the menu, so search in reverse
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

    /// Finds and selects a matching tab from the tab bar (AXTabGroup) inside a window.
    /// Electron-based apps have huge accessibility trees, so the search is limited to
    /// shallow levels and never descends into web content (AXWebArea).
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

    // MARK: - Debugging

    /// Prints the shallow levels of the AX tree (for structure investigation)
    static func dumpTree(bundleIds: [String], maxDepth: Int = 3) {
        guard AXIsProcessTrusted() else {
            print("Accessibility permission not granted")
            return
        }
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleId = app.bundleIdentifier, bundleIds.contains(bundleId) else { continue }
            print("=== \(bundleId) (pid \(app.processIdentifier)) ===")
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = elements(of: axApp, attribute: kAXWindowsAttribute) else {
                print("  (failed to get AXWindows)")
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

    // MARK: - AX helpers

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

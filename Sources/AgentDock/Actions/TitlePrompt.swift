import AppKit

/// Modal prompt for editing a session's display title.
/// Returns the entered text, "" when the user cleared the field (= reset),
/// or nil when cancelled.
@MainActor
enum TitlePrompt {
    static func ask(current: String?) -> String? {
        let alert = NSAlert()
        alert.messageText = loc("rename.title")
        alert.informativeText = loc("rename.detail")
        alert.addButton(withTitle: loc("rename.ok"))
        alert.addButton(withTitle: loc("rename.cancel"))

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        field.stringValue = current ?? ""
        field.placeholderString = loc("rename.placeholder")
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        // The panel is non-activating, so bring the app forward for the modal
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }
}

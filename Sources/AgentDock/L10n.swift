import Foundation

/// Localized string lookup for the SwiftPM resource bundle.
/// UI strings must go through these helpers — plain string literals in
/// SwiftUI views resolve against Bundle.main, which has no string tables.
func loc(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, comment: "")
}

func loc(_ key: String, _ args: CVarArg...) -> String {
    String(format: loc(key), arguments: args)
}

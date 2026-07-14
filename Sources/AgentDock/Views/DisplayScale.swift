import Foundation

/// Converts the text/icon display size setting (small/medium/large) into a scale factor.
/// UserDefaults stores "small" / "medium" / "large".
enum DisplayScale {
    static let textKey = "textSize"
    static let iconKey = "iconSize"
    static let defaultValue = "medium"

    static func text(_ raw: String) -> CGFloat {
        switch raw {
        case "small": return 1.0
        case "large": return 1.3
        default: return 1.15
        }
    }

    static func icon(_ raw: String) -> CGFloat {
        switch raw {
        case "small": return 1.0
        case "large": return 1.45
        default: return 1.2
        }
    }

    /// Icon size "large" makes rows taller, so the latest message can show 2 lines
    static func messageLineLimit(iconSize raw: String) -> Int {
        raw == "large" ? 2 : 1
    }
}

/// Relative time text for the list. A very recent timestamp that appears to be in the
/// future due to clock rounding error is shown as "now".
enum RelativeTime {
    static func string(for date: Date) -> String {
        if Date().timeIntervalSince(date) < 3 {
            return loc("time.now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

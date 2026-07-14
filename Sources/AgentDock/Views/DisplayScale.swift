import Foundation

/// 文字・アイコンの表示サイズ設定(小/中/大)を倍率に変換する。
/// UserDefaults には "small" / "medium" / "large" を保存する。
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

    /// アイコン「大」は行が高くなるため、最新メッセージを2行表示できる
    static func messageLineLimit(iconSize raw: String) -> Int {
        raw == "large" ? 2 : 1
    }
}

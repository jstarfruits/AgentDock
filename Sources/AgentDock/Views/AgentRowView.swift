import SwiftUI

/// セッション一覧の1行。クリックで該当の作業場所へ復帰する。
struct AgentRowView: View {
    let session: AgentSession
    var compact = false
    var isPinned = false
    var onTogglePin: (() -> Void)?

    @State private var isHovering = false
    /// 行の主表示をセッションタイトルにするか(オフならセッション名)。メニューから切替
    @AppStorage("showSessionTitles") private var showTitles = true
    @AppStorage(DisplayScale.textKey) private var textSize = DisplayScale.defaultValue
    @AppStorage(DisplayScale.iconKey) private var iconSize = DisplayScale.defaultValue

    private var primaryText: String {
        showTitles ? (session.title ?? session.name) : session.name
    }

    private var primaryFontSize: CGFloat {
        (compact ? 11 : 13) * DisplayScale.text(textSize)
    }

    private var secondaryFontSize: CGFloat {
        10 * DisplayScale.text(textSize)
    }

    var body: some View {
        Button {
            FocusAction.focus(session)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                iconWithStatusBadge

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(primaryText)
                            .font(.system(size: primaryFontSize, weight: .medium))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let onTogglePin, isHovering || isPinned {
                            Button(action: onTogglePin) {
                                Image(systemName: isPinned ? "pin.fill" : "pin")
                                    .font(.caption2)
                                    .foregroundStyle(isPinned ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                            }
                            .buttonStyle(.plain)
                            .help(isPinned ? "ピンを外す" : "常に上部に表示する")
                        }
                        Text(relativeTime)
                            .font(.system(size: secondaryFontSize))
                            .foregroundStyle(.secondary)
                    }
                    if !compact {
                        Text(session.displayPath)
                            .font(.system(size: secondaryFontSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    if let message = session.lastMessage {
                        Text(message)
                            .font(.system(size: secondaryFontSize))
                            .foregroundStyle(.tertiary)
                            .lineLimit(DisplayScale.messageLineLimit(iconSize: iconSize))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, compact ? 4 : 5)
            .background(
                isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("クリックで \(session.name) に戻る")
    }

    private var iconWithStatusBadge: some View {
        AgentIconView(session: session, size: (compact ? 18 : 22) * DisplayScale.icon(iconSize))
    }

    private var relativeTime: String {
        RelativeTime.string(for: session.lastActivity)
    }
}

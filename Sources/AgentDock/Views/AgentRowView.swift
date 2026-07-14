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

    private var primaryText: String {
        showTitles ? (session.title ?? session.name) : session.name
    }

    var body: some View {
        Button {
            FocusAction.focus(session)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                iconWithStatusBadge
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(primaryText)
                            .font(compact ? .caption : .callout)
                            .fontWeight(.medium)
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
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !compact {
                        Text(session.displayPath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    if let message = session.lastMessage {
                        Text(message)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
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
        AgentIconView(session: session, size: compact ? 18 : 22)
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: session.lastActivity, relativeTo: Date())
    }
}

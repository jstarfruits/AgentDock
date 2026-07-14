import SwiftUI

/// グリッド表示モードの1セル(アイコン+タイトルのみ)。クリックで復帰。
struct AgentGridCell: View {
    let session: AgentSession
    var isPinned = false

    @State private var isHovering = false
    @AppStorage("showSessionTitles") private var showTitles = true

    private var primaryText: String {
        showTitles ? (session.title ?? session.name) : session.name
    }

    var body: some View {
        Button {
            FocusAction.focus(session)
        } label: {
            VStack(spacing: 3) {
                AgentIconView(session: session, size: 26)
                    .overlay(alignment: .topTrailing) {
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.orange)
                                .offset(x: 4, y: -3)
                        }
                    }
                Text(primaryText)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 3)
            .frame(maxWidth: .infinity)
            .background(
                isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(helpText)
    }

    private var helpText: String {
        var lines = [primaryText, session.displayPath]
        if let message = session.lastMessage {
            lines.append(message)
        }
        return lines.joined(separator: "\n")
    }
}

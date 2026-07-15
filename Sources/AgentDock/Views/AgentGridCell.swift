import SwiftUI

/// A single cell in grid display mode (icon + title only). Clicking returns to the session.
struct AgentGridCell: View {
    let session: AgentSession
    var isPinned = false
    var onRename: (() -> Void)?
    var onResetTitle: (() -> Void)?

    @State private var isHovering = false
    @AppStorage("showSessionTitles") private var showTitles = true
    @AppStorage(DisplayScale.textKey) private var textSize = DisplayScale.defaultValue
    @AppStorage(DisplayScale.iconKey) private var iconSize = DisplayScale.defaultValue

    private var primaryText: String {
        showTitles ? (session.displayTitle ?? session.name) : session.name
    }

    var body: some View {
        Button {
            FocusAction.focus(session)
        } label: {
            VStack(spacing: 3) {
                AgentIconView(session: session, size: 26 * DisplayScale.icon(iconSize))
                    .overlay(alignment: .topTrailing) {
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.orange)
                                .offset(x: 4, y: -3)
                        }
                    }
                Text(primaryText)
                    .font(.system(size: 10 * DisplayScale.text(textSize)))
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
        .contextMenu {
            if let onRename {
                Button(loc("rename.menu"), action: onRename)
            }
            if session.customTitle != nil, let onResetTitle {
                Button(loc("rename.reset"), action: onResetTitle)
            }
        }
    }

    private var helpText: String {
        var lines = [primaryText, session.displayPath]
        if let message = session.lastMessage {
            lines.append(message)
        }
        return lines.joined(separator: "\n")
    }
}

import SwiftUI

/// Contents of the always-on-top panel. Lays out to follow the window size.
/// Displayed in order: pinned → needs attention → running → stalled (collapsible) → idle count.
struct FloatingPanelView: View {
    @ObservedObject var store: AgentStore
    @ObservedObject var panelState: PanelState

    @AppStorage("staleSectionExpanded") private var staleExpanded = false
    /// Grid display mode showing only icon + title
    @AppStorage("panelGridMode") private var gridMode = false
    @AppStorage(DisplayScale.textKey) private var textSize = DisplayScale.defaultValue

    private var mainSessions: [AgentSession] {
        store.pinnedSessions + store.attentionSessions + store.runningSessions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if mainSessions.isEmpty && store.staleSessions.isEmpty {
                Text(loc("panel.empty"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        sessionsView(mainSessions)
                        if !store.staleSessions.isEmpty {
                            staleSection
                        }
                    }
                    .padding(5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            if !store.idleSessions.isEmpty {
                Divider()
                Text(loc("panel.idleCount", store.idleSessions.count))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    /// Renders as list rows or a grid depending on the display mode
    @ViewBuilder
    private func sessionsView(_ sessions: [AgentSession]) -> some View {
        if gridMode {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88 * DisplayScale.text(textSize)), spacing: 4)],
                spacing: 4
            ) {
                ForEach(sessions) { session in
                    AgentGridCell(session: session, isPinned: store.isPinned(session))
                }
            }
        } else {
            ForEach(sessions) { session in
                row(session)
            }
        }
    }

    private func row(_ session: AgentSession) -> some View {
        AgentRowView(
            session: session,
            compact: true,
            isPinned: store.isPinned(session),
            onTogglePin: { store.togglePin(session) }
        )
    }

    /// Collapsible section for needs-attention sessions left unattended for a long time
    private var staleSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                staleExpanded.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: staleExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8))
                    Text(loc("panel.staleCount", store.staleSessions.count))
                        .font(.caption2)
                    Spacer()
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if staleExpanded {
                sessionsView(store.staleSessions)
                    .opacity(0.55)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            TrafficLightCloseButton {
                panelState.hide()
            }
            Text("Agent Dock")
                .font(.caption.bold())
            if store.needsAttentionCount > 0 {
                Text("\(store.needsAttentionCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.green, in: Capsule())
            }
            Spacer()
            Button {
                gridMode.toggle()
            } label: {
                Image(systemName: gridMode ? "list.bullet" : "square.grid.3x2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(gridMode ? loc("help.listMode") : loc("help.gridMode"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

/// A red circular button styled like macOS's traffic-light (close) button. Shows an × on hover.
private struct TrafficLightCloseButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.37, blue: 0.34))
                    .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
                if isHovering {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.black.opacity(0.55))
                }
            }
            .frame(width: 12, height: 12)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(loc("help.hidePanel"))
    }
}

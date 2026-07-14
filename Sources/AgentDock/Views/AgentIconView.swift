import SwiftUI

/// Shared view that overlays a status-color dot badge on the bottom-right of the running app's icon
struct AgentIconView: View {
    let session: AgentSession
    var size: CGFloat = 22

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            appIcon
                .frame(width: size, height: size)
            Circle()
                .fill(statusColor)
                .frame(width: dotSize, height: dotSize)
                .overlay(Circle().strokeBorder(.background, lineWidth: 1))
                .offset(x: 2, y: 2)
        }
    }

    private var dotSize: CGFloat {
        max(8, size * 0.36)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = AppIcons.icon(for: session) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "terminal")
                .font(.system(size: size - 6))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .needsAttention: return .green
        case .running: return .orange
        case .idle: return .secondary.opacity(0.5)
        }
    }
}

//  WorkspaceSwitcher.swift — SlateUI
//  Sélecteur de workspace en haut de la sidebar (placeholder Phase 3 → réel Phase 19).

import SwiftUI

public struct SlateWorkspace: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var systemImage: String
    public var accent: SlateAccent
    public init(id: UUID = UUID(), name: String, systemImage: String = "square.stack.3d.up.fill",
                accent: SlateAccent = .blue) {
        self.id = id; self.name = name; self.systemImage = systemImage; self.accent = accent
    }
}

public struct WorkspaceSwitcher: View {
    let current: SlateWorkspace
    var others: [SlateWorkspace] = []
    var onSelect: (SlateWorkspace) -> Void = { _ in }
    var onManage: () -> Void = {}

    @Environment(\.slateAccent) private var accent
    @State private var isHovering = false
    @FocusState private var focused: Bool

    public init(current: SlateWorkspace, others: [SlateWorkspace] = [],
                onSelect: @escaping (SlateWorkspace) -> Void = { _ in },
                onManage: @escaping () -> Void = {}) {
        self.current = current; self.others = others; self.onSelect = onSelect; self.onManage = onManage
    }

    public var body: some View {
        Menu {
            ForEach(others) { ws in
                Button { onSelect(ws) } label: { Label(ws.name, systemImage: ws.systemImage) }
            }
            if !others.isEmpty { Divider() }
            Button("Gérer les workspaces…", action: onManage)
        } label: {
            HStack(spacing: SlateSpace.s) {
                // Pastille d'identité : la couleur d'accent du workspace rend l'isolation visible.
                RoundedRectangle(cornerRadius: SlateRadius.s, style: .continuous)
                    .fill(current.accent.color)
                    .frame(width: SlateMetrics.controlM - 4, height: SlateMetrics.controlM - 4)
                    .overlay {
                        Image(systemName: current.systemImage)
                            .font(.system(size: SlateMetrics.iconS, weight: .semibold))
                            .foregroundStyle(current.accent.onAccent)
                    }
                VStack(alignment: .leading, spacing: 0) {
                    Text(current.name)
                        .slateFont(.listTitle)
                        .foregroundStyle(SlateColors.textPrimary)
                        .lineLimit(1)
                    Text("Workspace")
                        .slateFont(.caption)
                        .foregroundStyle(SlateColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: SlateSpace.xs)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SlateColors.textTertiary)
            }
            .padding(.horizontal, SlateSpace.s)
            .padding(.vertical, SlateSpace.s)
            .background {
                RoundedRectangle(cornerRadius: SlateRadius.m, style: .continuous)
                    .fill(isHovering ? SlateColors.stateHover : .clear)
            }
            .overlay {
                if focused {
                    RoundedRectangle(cornerRadius: SlateRadius.m, style: .continuous)
                        .strokeBorder(accent.focusRing, lineWidth: SlateStroke.focusRingWidth)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .focusable()
        .focused($focused)
        .onHover { isHovering = $0 }
        .padding(.horizontal, SlateSpace.s)
        .accessibilityLabel("Workspace \(current.name), changer de workspace")
    }
}

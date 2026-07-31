import SwiftUI
import SlateModel
import SlateUI

/// Ligne d'en-tete de la sidebar affichant le workspace courant.
///
/// Placeholder FONCTIONNEL au sens de `docs/03_sidebar_navigation.md` : affiche le
/// vrai workspace courant (pas une valeur inventee), mais reste desactive - le vrai
/// selecteur multi-workspace est construit en Phase 19 (voir `docs/GLOSSAIRE.md` §1).
struct WorkspaceSwitcherRow: View {
    let workspace: Workspace?

    var body: some View {
        Button {
            // Intentionnellement vide : selection multi-workspace = Phase 19.
        } label: {
            HStack(spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall, style: .continuous)
                    .fill(SlateColor.accentDefault)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: workspace?.iconName ?? "square.stack")
                            .slateIconFont(SlateGeometry.workspaceIconSize, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(SlateColor.textOnAccent)
                    }
                VStack(alignment: .leading, spacing: 0) {
                    Text(workspace?.name ?? String(localized: "sidebar.workspace.placeholderName", bundle: .module))
                        .slateFont(SlateFont.bodyEmphasis)
                        .foregroundStyle(SlateColor.textPrimary)
                        .lineLimit(1)
                    Text(String(localized: "sidebar.workspace.subtitle", bundle: .module))
                        .slateFont(SlateFont.caption)
                        .foregroundStyle(SlateColor.textSecondary)
                }
                Spacer(minLength: Spacing.xs)
                Image(systemName: "chevron.up.chevron.down")
                    .slateIconFont(SlateGeometry.workspaceChevronSize, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(SlateColor.textTertiary)
            }
            .padding(Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(true)
        .help(String(localized: "sidebar.workspace.switcherHelp", bundle: .module))
        .accessibilityLabel(workspace?.name ?? String(localized: "sidebar.workspace.placeholderName", bundle: .module))
        .accessibilityHint(String(localized: "sidebar.workspace.switcherHelp", bundle: .module))
    }
}

#Preview("WorkspaceSwitcherRow") {
    WorkspaceSwitcherRow(workspace: nil)
        .frame(width: 240)
        .slateSidebarBackground()
}

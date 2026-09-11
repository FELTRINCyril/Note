import SwiftUI
import SlateUI

/// Pied de la sidebar (spec E2 : "Pied : 40 pt, separateur 1 pt : Reglages - Corbeille
/// - puis nouveau dossier (Cmd+Maj+N) - nouvelle note (Cmd+N)").
///
/// Reglages ouvre la fenetre `SettingsWindowView` (Phase 13, voir `SidebarView`) via
/// `onOpenSettings`. Corbeille est fonctionnelle depuis la Phase 11 (`onOpenTrash`,
/// presente `TrashView` - voir `SidebarView`). Nouveau dossier/nouvelle note sont
/// fonctionnels, operant dans le dossier selectionne (voir `SidebarView`).
struct SidebarFooterView: View {
    let canCreateNote: Bool
    let onOpenSettings: () -> Void
    let onOpenTrash: () -> Void
    let onNewFolder: () -> Void
    let onNewNote: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help(String(localized: "sidebar.footer.settings.help", bundle: .module))
            .accessibilityLabel(String(localized: "sidebar.footer.settings", bundle: .module))

            Button(action: onOpenTrash) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .help(String(localized: "sidebar.footer.trash.help", bundle: .module))
            .accessibilityLabel(String(localized: "sidebar.footer.trash", bundle: .module))

            Spacer(minLength: Spacing.xs)

            Button(action: onNewFolder) {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .help(String(localized: "sidebar.footer.newFolder.help", bundle: .module))
            .accessibilityLabel(String(localized: "sidebar.footer.newFolder", bundle: .module))

            Button(action: onNewNote) {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .disabled(!canCreateNote)
            .help(
                canCreateNote
                    ? String(localized: "sidebar.footer.newNote.help", bundle: .module)
                    : String(localized: "sidebar.footer.newNote.disabledHelp", bundle: .module)
            )
            .accessibilityLabel(String(localized: "sidebar.footer.newNote", bundle: .module))
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SlateGeometry.sidebarFooterHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle().fill(SlateColor.separator).frame(height: 1)
        }
        .foregroundStyle(SlateColor.textSecondary)
    }
}

#Preview("SidebarFooterView") {
    SidebarFooterView(
        canCreateNote: true,
        onOpenSettings: {},
        onOpenTrash: {},
        onNewFolder: {},
        onNewNote: {}
    )
    .frame(width: 240)
    .slateSidebarBackground()
}

#Preview("SidebarFooterView - sans dossier selectionne") {
    SidebarFooterView(
        canCreateNote: false,
        onOpenSettings: {},
        onOpenTrash: {},
        onNewFolder: {},
        onNewNote: {}
    )
    .frame(width: 240)
    .slateSidebarBackground()
    .preferredColorScheme(.dark)
}

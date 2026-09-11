import SwiftUI
import SwiftData
import SlateModel
import SlateUI

/// Vue dediee Corbeille (design P3, artboard B) : en-tete "Corbeille / N notes", bouton
/// "Vider la corbeille" (visible mais desactive si vide - design : "la position du
/// bouton ne bouge pas quand des notes arrivent"), bandeau d'explication de la purge a
/// 30 jours, liste des notes avec Restaurer/Supprimer (ou "Deverrouiller pour restaurer"
/// pour une note verrouillee, voir `TrashRowView`).
///
/// Presentee en feuille depuis `SidebarFooterView` (voir `SidebarView`) : cette phase
/// n'introduit pas de route/navigation dediee, la Corbeille est une destination modale
/// comme les autres feuilles de la sidebar (`FolderNamePromptSheet`,
/// `FolderIconPickerSheet`).
/// Pas de `#Preview` sur cette vue elle-meme, meme rationale que `NoteListView`/
/// `SidebarView` (assemblage alimente par `AppState` + `@Query` en direct) : les
/// sous-vues qui la composent (`TrashRowView`, `TrashEmptyStateView`,
/// `DeletePermanentlyConfirmationOverlay`) ont chacune leurs propres previews.
public struct TrashView: View {
    @Environment(\.appState) private var appState
    @Environment(\.noteActions) private var noteActions
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Note> { $0.isTrashed }, sort: [SortDescriptor(\Note.trashedAt, order: .reverse)])
    private var trashedNotesQuery: [Note]

    @State private var deleteTarget: Note?
    @State private var showsEmptyTrashConfirmation = false

    public init() {}

    private var trashedNotes: [Note] {
        guard let workspace = appState.selectedWorkspace else { return trashedNotesQuery }
        return trashedNotesQuery.filter { $0.folder?.space?.workspace?.id == workspace.id }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            if trashedNotes.isEmpty {
                TrashEmptyStateView()
                    .frame(maxHeight: .infinity)
            } else {
                banner
                list
            }
        }
        .frame(minWidth: 480, idealWidth: 600, minHeight: 360, idealHeight: 480)
        .background(SlateColor.bgList)
        .overlay {
            if let deleteTarget {
                DeletePermanentlyConfirmationOverlay(
                    noteTitle: deleteTarget.title,
                    attachmentCount: NoteAttachmentCounter.count(in: deleteTarget),
                    onCancel: { self.deleteTarget = nil },
                    onConfirm: { confirmDeletePermanently(deleteTarget) }
                )
            }
        }
        .confirmationDialog(
            emptyTrashConfirmationTitle,
            isPresented: $showsEmptyTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "trash.emptyConfirm.confirm", bundle: .module), role: .destructive) {
                emptyTrash()
            }
            Button(String(localized: "action.cancel", bundle: .module), role: .cancel) {}
        }
    }

    // MARK: - En-tete

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "trash")
                .slateIconFont(SlateGeometry.toolbarIconSize, relativeTo: .subheadline)
                .foregroundStyle(SlateColor.textSecondary)
            Text(String(localized: "trash.title", bundle: .module))
                .slateFont(SlateFont.bodyEmphasis)
                .foregroundStyle(SlateColor.textPrimary)
            Text(noteCountText)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textSecondary)
            Spacer(minLength: Spacing.sm)
            Button(String(localized: "trash.emptyButton", bundle: .module)) {
                showsEmptyTrashConfirmation = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(Self.isEmptyTrashButtonDisabled(noteCount: trashedNotes.count))
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SlateGeometry.sidebarFooterHeight + Spacing.xs)
        .overlay(alignment: .bottom) {
            Rectangle().fill(SlateColor.separator).frame(height: SlateGeometry.strokeHairline)
        }
    }

    private var noteCountText: String {
        switch trashedNotes.count {
        case 0:
            return String(localized: "trash.count.zero", bundle: .module)
        case 1:
            return String(localized: "trash.count.one", bundle: .module)
        default:
            let template = String(localized: "trash.count.many", bundle: .module)
            return String(format: template, trashedNotes.count)
        }
    }

    // MARK: - Bandeau

    private var banner: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.circle")
                .slateIconFont(SlateGeometry.noteCellIndicatorIconSize, relativeTo: .caption)
                .foregroundStyle(SlateColor.semanticWarningText)
            Text(String(format: bannerTemplate, TrashRetentionPolicy.retentionDays))
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textPrimary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SlateColor.semanticWarningSubtle)
        .overlay(alignment: .bottom) {
            Rectangle().fill(SlateColor.separator).frame(height: SlateGeometry.strokeHairline)
        }
    }

    private var bannerTemplate: String {
        String(localized: "trash.banner.retention", bundle: .module)
    }

    // MARK: - Liste

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(trashedNotes) { note in
                    TrashRowView(
                        note: note,
                        now: .now,
                        calendar: .current,
                        onRestore: { restore(note) },
                        onDeletePermanently: { deleteTarget = note }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func restore(_ note: Note) {
        try? noteActions.restore([note])
    }

    private func confirmDeletePermanently(_ note: Note) {
        try? noteActions.deletePermanently([note])
        deleteTarget = nil
    }

    private func emptyTrash() {
        try? noteActions.deletePermanently(trashedNotes)
    }

    private var emptyTrashConfirmationTitle: String {
        let template = String(localized: "trash.emptyConfirm.title", bundle: .module)
        return String(format: template, trashedNotes.count)
    }
}

extension TrashView {
    /// "Vider la corbeille" reste TOUJOURS visible mais desactive quand la corbeille est
    /// vide (design P3, artboard B : "la position du bouton ne bouge pas quand des
    /// notes arrivent") - jamais masque. Extrait en fonction pure et `static`, meme motif
    /// que `NoteListView.shouldFlattenDateGroups(for:)`, pour rester testable sans
    /// construire de vue ni de `ModelContainer`.
    static func isEmptyTrashButtonDisabled(noteCount: Int) -> Bool {
        noteCount == 0
    }
}

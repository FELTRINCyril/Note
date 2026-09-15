import SlateModel
import SlateUI
import SwiftData
import SwiftUI

/// Rendu d'un bloc `pageLink` (Phase 16, docs/16_liens_internes.md) : lien cliquable
/// vers une autre note, titre RESOLU DYNAMIQUEMENT depuis `BlockAttributes.
/// linkedNoteID` (jamais stocke sur le bloc lui-meme -- docs/16, critere "titre resolu
/// dynamiquement... le lien doit afficher le nouveau titre" si la cible est renommee),
/// et etat "page supprimee" lisible si la cible n'existe plus (docs/16, "Orphelins").
///
/// Ne porte aucun `RichText`/`NSTextView` (voir `BlockRenderKind.pageLink`) : le clic
/// est la SEULE interaction, exactement comme `DividerBlockView`/`TableBlockContentView`
/// n'ont pas de caret propre. La navigation elle-meme remonte via
/// `EditorController.onNavigateToNote` : `SlateEditor` ne connait aucune notion de
/// selection d'app (voir sa documentation de tete pour le sens des dependances).
struct PageLinkBlockContentView: View {
    let block: Block
    let editorController: EditorController

    /// `nil` tant que la resolution n'a pas encore eu lieu (juste apres montage) --
    /// distinct de "vide" : un titre vide legitime (note "Sans titre") ne doit jamais
    /// se confondre avec "pas encore resolu".
    @State private var resolvedNote: Note?
    @State private var isOrphan = false

    var body: some View {
        Button(action: navigate) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isOrphan ? "questionmark.square.dashed" : "doc.text")
                    .slateIconFont(SlateGeometry.sidebarIconSize)
                    .foregroundStyle(isOrphan ? SlateColor.textTertiary : SlateColor.textSecondary)
                Text(displayedTitle)
                    .slateFont(SlateFont.body)
                    .foregroundStyle(isOrphan ? SlateColor.textTertiary : SlateColor.textPrimary)
                    .strikethrough(isOrphan)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall, style: .continuous)
                    .fill(SlateColor.surfaceSecondary)
            )
        }
        .buttonStyle(.plain)
        .disabled(isOrphan)
        .accessibilityLabel(isOrphan ? EditorStrings.pageLinkDeletedPage : displayedTitle)
        .onAppear(perform: resolveLinkedNote)
        .onChange(of: block.attributes.linkedNoteID) { _, _ in resolveLinkedNote() }
    }

    private var displayedTitle: String {
        if isOrphan { return EditorStrings.pageLinkDeletedPage }
        let title = resolvedNote?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? EditorStrings.pageLinkUntitled : title
    }

    /// Resout `resolvedNote`/`isOrphan` depuis `BlockAttributes.linkedNoteID` -- jamais
    /// depuis une valeur stockee sur `block` lui-meme (voir la documentation de tete de
    /// fichier). Recalcule aussi a chaque changement de `linkedNoteID` (ne devrait
    /// normalement jamais changer une fois le bloc cree, mais reste coherent si un
    /// futur outil de reparation de lien le faisait).
    private func resolveLinkedNote() {
        guard let linkedNoteID = block.attributes.linkedNoteID, let modelContext = editorController.modelContext else {
            isOrphan = true
            resolvedNote = nil
            return
        }
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == linkedNoteID })
        guard let note = try? modelContext.fetch(descriptor).first else {
            isOrphan = true
            resolvedNote = nil
            return
        }
        isOrphan = false
        resolvedNote = note
    }

    private func navigate() {
        guard !isOrphan else { return }
        resolveLinkedNote()
        guard let resolvedNote else { return }
        editorController.onNavigateToNote?(resolvedNote)
    }
}

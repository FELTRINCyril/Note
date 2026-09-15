import SlateModel
import SlateUI
import SwiftUI

/// Overlay du selecteur de page "@"/"[[" (Phase 16, docs/16_liens_internes.md) --
/// reutilise STRICTEMENT le meme patron que `SlashMenuOverlay` (Phase 6, voir sa
/// documentation de tete pour la justification complete : un overlay SwiftUI ancre par
/// calcul, jamais un `.popover`, pour que la frappe continue d'aller au `NSTextView` du
/// bloc pendant que la liste se filtre) et le meme composant de rendu, `SlashMenuView`
/// (une seule section ici, "Pages", plus l'entree "Creer la page..." quand elle
/// s'applique -- voir `EditorController.shouldOfferPageMentionCreation(for:)`).
struct PageMentionOverlay: View {
    let block: Block
    let editorController: EditorController

    var body: some View {
        if let frame = editorController.blockFrames[block.id] {
            SlashMenuView(
                sections: sections,
                selectedItemID: editorController.pageMentionState?.selectedItemID,
                emptyStateMessage: EditorStrings.pageMentionEmptyState,
                onSelect: { itemID in editorController.confirmPageMentionSelection(itemID, in: block) },
                onHover: { itemID in editorController.hoverPageMentionItem(itemID) }
            )
            // Meme ancrage que `SlashMenuOverlay` : coin superieur gauche du CADRE DU
            // BLOC, voir sa documentation de tete, "Geometrie", pour la limite connue.
            .offset(x: frame.minX, y: frame.maxY)
        }
    }

    private var sections: [SlashMenuView.Section] {
        var items = editorController.pageMentionMatches(for: block).map(item(for:))
        if editorController.shouldOfferPageMentionCreation(for: block) {
            items.append(createItem)
        }
        guard !items.isEmpty else { return [] }
        return [SlashMenuView.Section(id: "pages", title: EditorStrings.pageMentionSectionTitle, items: items)]
    }

    private func item(for match: NoteMentionMatch) -> SlashMenuView.Item {
        let title = match.candidate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return SlashMenuView.Item(
            id: match.candidate.id.uuidString,
            title: title.isEmpty ? EditorStrings.pageLinkUntitled : title,
            subtitle: "",
            systemImage: "doc.text",
            matchedTitleOffsets: []
        )
    }

    private var createItem: SlashMenuView.Item {
        let query = editorController.pageMentionState?.query.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return SlashMenuView.Item(
            id: EditorController.pageMentionCreateSentinel,
            title: EditorStrings.pageMentionCreateTitle(query),
            subtitle: EditorStrings.pageMentionCreateSubtitle,
            systemImage: "plus.circle",
            matchedTitleOffsets: []
        )
    }
}

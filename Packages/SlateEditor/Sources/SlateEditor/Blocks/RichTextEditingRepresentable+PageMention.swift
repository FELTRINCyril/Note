import AppKit
import SlateModel
import SwiftData

/// Selecteur de page "@"/"[[" et resolution du lien interne `slate://note/<uuid>`
/// (Phase 16, docs/16_liens_internes.md), extrait de `RichTextEditingRepresentable.swift`
/// pour rester sous la limite de longueur de fichier de `CLAUDE.md` §5 -- meme motif
/// exact que `+Rendering.swift` (Phase 8) : meme type `Coordinator`, aucune nouvelle
/// surface publique, `block`/`editorController`/`modelContext` restent `internal`.
extension RichTextEditingRepresentable.Coordinator {
    // MARK: - Selecteur de page "@"/"[[" (`RichTextBlockLifecycleDelegate`)

    func richTextViewShouldHandlePageMentionMoveSelection(_ direction: BlockSelectionDirection) -> Bool {
        editorController.movePageMentionSelection(direction, in: block)
    }

    func richTextViewShouldHandlePageMentionReturn() -> Bool {
        editorController.handlePageMentionReturn(in: block)
    }

    func richTextViewShouldHandlePageMentionEscape() -> Bool {
        editorController.handlePageMentionEscape(in: block)
    }

    // MARK: - Lien interne `slate://note/<uuid>` (`NSTextViewDelegate`)

    /// Interception du clic (Cmd+clic, comportement natif d'un `NSTextView` EDITABLE)
    /// sur un lien inline deja pose par le popover d'edition de lien (Phase 7,
    /// `LinkEditorPopoverView`) : si l'URL cliquee suit le schema interne
    /// (`SlateNoteURLResolver`), navigue DANS l'app plutot que de laisser AppKit tenter
    /// de l'ouvrir via `NSWorkspace` (qui echouerait silencieusement, aucune
    /// application n'etant enregistree pour ce schema hors de ce process). Toute autre
    /// URL (http/https...) retombe sur le comportement natif inchange -- `false` laisse
    /// `NSTextView` gerer l'ouverture lui-meme, exactement comme avant cette phase.
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = (link as? URL) ?? (link as? String).flatMap(URL.init(string:)),
              let noteID = SlateNoteURLResolver.noteID(in: url) else { return false }

        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteID })
        guard let targetNote = try? modelContext.fetch(descriptor).first else { return true }
        editorController.onNavigateToNote?(targetNote)
        return true
    }
}

import Foundation

/// Chaines du glisser-deposer et de la mise en colonnes (Phase 10,
/// docs/10_dragdrop_colonnes.md) -- extrait de `EditorStrings.swift` pour rester sous la
/// limite de longueur de fichier de `CLAUDE.md` §5, meme motif exact que
/// `EditorStrings+Media.swift`/`EditorStrings+SpecialBlocks.swift` (Phases 8/9). Meme
/// type (`EditorStrings`), aucune nouvelle surface publique qui lui soit propre.
extension EditorStrings {
    /// Annonce VoiceOver a chaque deplacement clavier d'un bloc (Ctrl+Cmd+fleche
    /// haut/bas, docs/10 : "annonce VoiceOver du type deplace en position 2 sur 5").
    static func blockMoveAccessibilityAnnouncement(position: Int, total: Int) -> String {
        let template = String(localized: "editor.blockMenu.moveUp.accessibilityAnnouncement", bundle: .module)
        return String(format: template, position, total)
    }

    /// Badge de comptage sur la ligne d'insertion d'un depot de fichiers (artboard C,
    /// P2) : n'apparait qu'a partir de 2 fichiers, voir `BlockDropIndicatorView`.
    static func dropzoneFileCount(_ count: Int) -> String {
        let template = String(localized: "editor.dropzone.fileCount", bundle: .module)
        return String(format: template, count)
    }

    /// Voile de depot sur la note entiere (fichiers deposes hors de tout bloc precis) :
    /// resume affiche par `NoteDropOverlayView`.
    static var dropzoneNoteDestinationSummary: String {
        String(localized: "editor.dropzone.noteDestinationSummary", bundle: .module)
    }
}

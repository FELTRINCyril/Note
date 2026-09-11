import SwiftUI

/// Point d'entree clavier "Focus editeur" (Phase 14, `docs/RACCOURCIS.md`) publie par
/// `NoteDocumentView` via `.focusedSceneValue(\.editorFocusAction, ...)`. `SlateEditor`
/// ne connait pas `SlateFeatures` (sens des dependances, `docs/00_architecture.md`) :
/// cette extension ne depend que de `SwiftUI`, exactement comme `FocusedValues`
/// elle-meme -- `SlateFeatures` (qui importe deja `SlateEditor`) peut la lire depuis
/// `SlateAppCommands` (`@FocusedValue(\.editorFocusAction)`) sans creer de dependance
/// inverse.
///
/// Volontairement TRES etroit : selectionne le premier bloc de premier niveau via
/// `EditorController.selectBlock(_:)`, le MEME point d'entree public deja utilise par
/// le clic simple sur un bloc (`BlockTreeView.plainSelectTapGesture`) -- aucune
/// modification du focus AppKit interne (`RichTextEditingTextView`,
/// `performKeyEquivalent`, premier repondant) n'a lieu ici. Une fois le bloc
/// selectionne, `Retour` (deja cable, voir `BlockTreeView.onKeyPress(.return)` ->
/// `EditorController.handleEnterOnSelectedBlock()`) permet d'entrer en edition -- geste
/// clavier deja existant, pas un ajout de cette phase.
@MainActor
private struct EditorFocusActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

@MainActor
extension FocusedValues {
    /// Deplace la selection clavier sur le premier bloc de la note affichee. `nil` si
    /// aucun bloc n'existe (note vide) ou si aucune note n'est affichee -- l'entree de
    /// menu correspondante (`SlateAppCommands`) se desactive alors automatiquement.
    public var editorFocusAction: (() -> Void)? {
        get { self[EditorFocusActionKey.self] }
        set { self[EditorFocusActionKey.self] = newValue }
    }
}

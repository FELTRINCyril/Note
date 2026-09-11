import Foundation
import SlateModel

/// Etat du menu de commandes "/" ouvert pour UN bloc precis (docs/06_slash_commandes.md,
/// sous-etape 6.3). Type pur (aucun AppKit) : `anchorOffset` fige la position du `/`
/// lui-meme dans le texte du bloc au moment de l'ouverture, `query` est recalculee a
/// chaque frappe par `EditorController.updateSlashMenuState(for:plainText:caretOffset:)`.
///
/// Extrait de `EditorController+SlashMenu.swift` (qui porte toute la LOGIQUE du menu)
/// uniquement pour rester sous la limite de longueur de fichier de `CLAUDE.md` §5 --
/// meme motif que `BlockSelectionRange.swift`, separe de `BlockSelectionOperations.swift`.
public struct SlashMenuState: Equatable, Sendable {
    let blockID: UUID
    /// Offset de CARACTERES (`RichTextOffset`, jamais un `Int` nu -- voir sa
    /// documentation) du `/` lui-meme dans `Block.text.plainText`. Le `/` reste dans le
    /// texte pendant toute la duree d'ouverture du menu (spec 6.4 : "le / RESTE dans le
    /// texte tant que le menu est ouvert") -- ce n'est qu'a l'execution
    /// (`EditorController.executeSlashCommand(_:in:)`) qu'il est retire, avec le reste
    /// de la requete.
    let anchorOffset: RichTextOffset
    /// Texte tape entre le `/` et le caret, recalcule a chaque frappe. Peut etre vide
    /// (menu juste ouvert, ou requete effacee sans fermer le menu).
    var query: String
    /// Identifiant de la commande actuellement mise en avant (`SlashCommand.id`),
    /// pilote au clavier (fleches) et par le survol souris. `nil` seulement quand
    /// aucune commande ne correspond a `query` (etat vide -- voir `SlashMenuView`).
    var selectedCommandID: String?
}

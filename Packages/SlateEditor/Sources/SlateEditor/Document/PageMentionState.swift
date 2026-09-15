import Foundation
import SlateModel

/// Etat du selecteur de page "@"/"[[" ouvert pour UN bloc precis (docs/16_liens_internes.md).
/// Meme role et meme forme que `SlashMenuState` (Phase 6) pour le menu "/" -- voir sa
/// documentation de tete pour la justification generale de cette forme (type pur,
/// aucun AppKit, `anchorOffset` fige au moment de l'ouverture, `query` recalculee a
/// chaque frappe par `EditorController.updatePageMentionState(for:plainText:caretOffset:)`).
///
/// Extrait dans son propre fichier pour la meme raison que `SlashMenuState` : rester
/// sous la limite de longueur de fichier de `CLAUDE.md` §5.
public struct PageMentionState: Equatable, Sendable {
    let blockID: UUID
    /// Offset de CARACTERES du DEBUT du declencheur ("@" ou "[[") dans
    /// `Block.text.plainText`. Reste dans le texte tant que le selecteur est ouvert,
    /// meme motif que `SlashMenuState.anchorOffset` pour le "/".
    let anchorOffset: RichTextOffset
    /// Texte exact du declencheur ("@" ou "[["), pour re-verifier a chaque frappe qu'il
    /// est toujours present a `anchorOffset` (voir `EditorController+PageMention.swift`,
    /// `recomputedQuery`) et connaitre sa longueur a l'execution/fermeture.
    let anchorText: String
    /// Texte tape entre le declencheur et le caret, recalcule a chaque frappe.
    var query: String
    /// Identifiant de l'entree actuellement mise en avant (`PageMentionItem.id` -- soit
    /// l'`UUID` d'une note existante sous forme de chaine, soit le jeton
    /// `PageMentionSelection.createSentinel` pour l'entree "Creer la page..."). `nil`
    /// seulement quand aucune entree n'est proposable (requete encore vide).
    var selectedItemID: String?
}

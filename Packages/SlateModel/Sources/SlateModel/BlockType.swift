import Foundation

/// Type d'un bloc de contenu, determine son rendu et son comportement dans l'editeur.
///
/// Enum `String`-backed pour rester compatible CloudKit (qui ne stocke pas les enums
/// entiers de facon fiable entre versions) et pour rester lisible en base en cas de
/// debug direct du store.
///
/// Important : les `rawValue` sont ecrits en base des la premiere note creee. Ils ne
/// doivent **jamais** etre modifies une fois des donnees ecrites (renommer un cas
/// changerait silencieusement le type de tous les blocs existants). Ajouter un nouveau
/// cas est sans risque ; renommer ou supprimer un cas existant ne l'est pas.
public enum BlockType: String, CaseIterable, Codable, Sendable {
    /// Paragraphe de texte standard.
    case paragraph

    /// Titres de niveau 1 a 6.
    case heading1
    case heading2
    case heading3
    case heading4
    case heading5
    case heading6

    /// Item de liste a puces. L'imbrication (sous-items) passe par `Block.parent`/`children`.
    case bulletedList
    /// Item de liste numerotee. Meme mecanisme d'imbrication que `bulletedList`.
    case numberedList
    /// Item de liste a cocher (case a cocher dans `BlockAttributes.isChecked`).
    case todo

    /// Citation.
    case quote
    /// Encadre mis en avant (callout), avec icone optionnelle dans `BlockAttributes.calloutIcon`.
    case callout
    /// Bloc de code, langage dans `BlockAttributes.language`.
    case code
    /// Separateur horizontal, sans contenu texte ni attributs.
    case divider

    /// Image, binaire porte par `Block.attachment`.
    case image
    /// Fichier joint quelconque, binaire porte par `Block.attachment`.
    case file

    /// Tableau (structure dediee, cf. Phase 8).
    case table

    /// Conteneur de colonnes (cf. Phase 10). Porte des blocs enfants de type `column`.
    case columnList
    /// Une colonne au sein d'un `columnList`. Porte ses propres blocs enfants.
    case column

    /// Apercu de lien externe enrichi (v2).
    case bookmark
    /// Contenu externe embarque, ex. video (v2).
    case embed

    /// Vue de base de donnees inline (v2, cf. Phase 17).
    case databaseView
    /// Lien vers une autre note ("sous-page", cf. Phase 16). Le nom reste `pageLink`
    /// pour la lisibilite du code ; l'UI dit "lien vers une note" (voir GLOSSAIRE).
    case pageLink
}

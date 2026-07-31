import SwiftUI

/// Tokens de typographie semantiques de Slate.
///
/// Phase 1 : bases uniquement sur les styles systeme (`Font.TextStyle`) pour respecter
/// nativement le Dynamic Type. Le mapping fin taille/poids/interligne de
/// `design/tokens.md` §9 (title.note, h1..h6, body, mono...) sera affine en Phase 13
/// (design reel), une fois que Claude Design aura fourni ses specs. Aucune vue ne doit
/// utiliser `.font(.system(size:))` directement : toujours passer par ce type.
public enum SlateFont {
    /// Titre principal d'une note. Style systeme `.largeTitle`.
    public static let titleNote: Font = .largeTitle.bold()

    /// Titre secondaire (en-tetes de section). Style systeme `.title2`.
    public static let titleSecondary: Font = .title2.bold()

    /// Sous-titre. Style systeme `.headline`.
    public static let subtitle: Font = .headline

    /// Corps de texte. Style systeme `.body`.
    public static let body: Font = .body

    /// Corps de texte accentue. Style systeme `.body`, poids semibold.
    public static let bodyEmphasis: Font = .body.weight(.semibold)

    /// Legende / metadonnee. Style systeme `.caption`.
    public static let caption: Font = .caption

    /// Libelle d'UI / bouton. Style systeme `.callout`.
    public static let label: Font = .callout

    /// Ligne de barre laterale. Style systeme `.subheadline`.
    public static let sidebarItem: Font = .subheadline

    /// Titre de cellule dans la liste de notes. Style systeme `.subheadline`, semibold.
    public static let listTitle: Font = .subheadline.weight(.semibold)

    /// Extrait de note dans la liste. Style systeme `.footnote`.
    public static let listSnippet: Font = .footnote
}

import SlateModel

/// Apparence a rendre pour un `BlockType`, independante de SwiftUI : c'est cette
/// enumeration, pas la vue elle-meme, qui porte l'exhaustivite du routage (voir
/// `BlockRenderRouting.kind(for:)`). La separer de la vue permet de tester
/// l'exhaustivite sans instancier de hierarchie SwiftUI (`SlateEditorTests`).
public enum BlockRenderKind: Equatable, Sendable {
    case paragraph
    case heading(level: Int)
    case divider
    case bulletedListItem
    case numberedListItem
    case todoItem
    case quote
    case code
    /// Encadre mis en avant (Phase 8, artboard F). `tableRow`/`tableCell` ne routent
    /// JAMAIS ici individuellement : ce sont des blocs de STRUCTURE INTERNE d'un
    /// `table`, rendus tous ensemble par `TableBlockContentView` -- voir `.table`
    /// ci-dessous et `BlockTreeView` (qui ne recurse pas dans les enfants d'un
    /// `table`, contrairement a un item de liste imbrique).
    case callout
    /// Tableau (Phase 8, artboard H). Un seul cas pour tout le tableau : ses lignes et
    /// cellules (`tableRow`/`tableCell`) ne sont pas des blocs de premier niveau du
    /// point de vue du rendu, meme si elles restent des `Block` a part entiere cote
    /// modele (voir `Block+Table.swift`).
    case table
    /// Bloc image (Phase 9, artboard A) : 4 etats (vide/depot, survol de depot,
    /// chargement, affichee/selectionnee), voir `ImageBlockContentView`. Ne porte
    /// aucun `RichText` -- ni convertible (`BlockConversion.convertibleTypes`), ni
    /// destinataire du caret, meme motif que `.divider`/`.table`.
    case image
    /// Bloc fichier joint (Phase 9, artboard B) : une seule piece jointe par bloc, voir
    /// `FileBlockContentView`. Memes exclusions que `.image` ci-dessus.
    case file
    /// Type de bloc dont le rendu riche n'est pas encore construit (hors perimetre de
    /// la phase en cours, ou reserve a une phase ulterieure : `columnList`/`column`
    /// (Phase 10), `bookmark`/`embed`/`databaseView`/`pageLink` (v2)), ou bloc de
    /// structure interne jamais rendu directement (`tableRow`/`tableCell`, voir
    /// `.table` ci-dessus). Porte le `BlockType` d'origine pour que le rendu de repli
    /// reste identifiable plutot qu'invisible.
    case unsupported(BlockType)
}

/// Association `BlockType` -> `BlockRenderKind`.
///
/// Le `switch` ci-dessous est volontairement EXHAUSTIF (pas de `default`) : ajouter un
/// nouveau `BlockType` sans mettre a jour cette fonction est une erreur de
/// COMPILATION, jamais un cas silencieusement ignore par un rendu par defaut. C'est
/// exactement la garantie demandee pour la Phase 5.1 ("aucun type de bloc ne doit etre
/// INVISIBLE").
public enum BlockRenderRouting {
    public static func kind(for type: BlockType) -> BlockRenderKind {
        switch type {
        case .paragraph:
            return .paragraph
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6:
            return .heading(level: headingLevel(for: type))
        case .bulletedList:
            return .bulletedListItem
        case .numberedList:
            return .numberedListItem
        case .todo:
            return .todoItem
        case .quote:
            return .quote
        case .code:
            return .code
        case .divider:
            return .divider
        case .callout:
            return .callout
        case .table:
            return .table
        case .image, .file:
            return type == .image ? .image : .file
        case .tableRow, .tableCell, .columnList, .column, .bookmark, .embed, .databaseView, .pageLink:
            // Un seul cas fusionne (complexite cyclomatique, `CLAUDE.md` Sec.5) pour
            // deux familles distinctes qui partagent la MEME reponse : structure
            // interne d'un tableau jamais rendue individuellement
            // (`tableRow`/`tableCell`, voir la documentation de `BlockRenderKind`) et
            // types reserves a une phase ulterieure (colonnes -- Phase 10 -- et v2 --
            // bookmark/embed/databaseView/pageLink). `tableRow`/`tableCell` ne sont en
            // pratique jamais atteints par un appelant de ce module (`BlockTreeView` ne
            // recurse pas dans les enfants d'un `table`), mais doivent rester couverts
            // pour la compilation exhaustive de ce `switch`.
            return .unsupported(type)
        }
    }

    /// Niveau (1 a 6) d'un `BlockType` de titre. Appelant garantit deja (via le
    /// `switch` ci-dessus) que `type` est l'un des 6 cas `headingN` : le `default`
    /// n'est atteignable que si ce contrat est rompu, ce qui ne peut arriver que par
    /// une erreur d'appel interne a ce fichier, jamais par un `BlockType` externe non
    /// traite (celui-la resterait dans le `switch` exhaustif ci-dessus).
    private static func headingLevel(for type: BlockType) -> Int {
        switch type {
        case .heading1: 1
        case .heading2: 2
        case .heading3: 3
        case .heading4: 4
        case .heading5: 5
        case .heading6: 6
        default: 1
        }
    }
}

import SwiftUI

/// Description d'un style typographique Slate : taille de base, poids, style de texte
/// systeme de reference (pour la mise a l'echelle Dynamic Type), et options fines
/// (chiffres tabulaires, tracking).
///
/// Type dedie plutot que des `Font` statiques : un `Font.system(size:)` ne suit PAS le
/// Dynamic Type tant qu'il n'est pas mis a l'echelle explicitement. `SlateTextStyle`
/// porte l'information necessaire a `View.slateFont(_:)` pour appliquer cette mise a
/// l'echelle via `@ScaledMetric` (design/tokens.md §9 : "Exprimer en Dynamic Type").
public struct SlateTextStyle: Sendable, Equatable {
    public let size: CGFloat
    public let weight: Font.Weight
    public let relativeTo: Font.TextStyle
    public let tabularNums: Bool
    public let tracking: CGFloat

    public init(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo: Font.TextStyle = .body,
        tabularNums: Bool = false,
        tracking: CGFloat = 0
    ) {
        self.size = size
        self.weight = weight
        self.relativeTo = relativeTo
        self.tabularNums = tabularNums
        self.tracking = tracking
    }
}

/// Tokens de typographie semantiques de Slate, alignes sur `design/tokens.md` §9 et sur
/// la spec E2 (`design/03_sidebar/Slate_E1-E2_coquille-sidebar.html`, "Specifications E2").
///
/// Aucune vue ne doit utiliser `.font(.system(size:))` directement : toujours passer par
/// `View.slateFont(_:)` avec un de ces tokens, pour beneficier de la mise a l'echelle
/// Dynamic Type.
public enum SlateFont {
    // MARK: - Barre laterale (spec E2)

    /// Ligne de sidebar. 13 pt Regular.
    public static let sidebarItem = SlateTextStyle(size: 13, weight: .regular, relativeTo: .subheadline)

    /// Compteur de ligne de sidebar. 12 pt Regular, chiffres tabulaires (pour que le
    /// libelle ne "danse" pas quand le nombre change).
    public static let sidebarCounter = SlateTextStyle(
        size: 12,
        weight: .regular,
        relativeTo: .caption,
        tabularNums: true
    )

    /// En-tete de section de sidebar. 11 pt Semibold, majuscules (applique par la vue),
    /// tracking 0,4.
    public static let sidebarSectionHeader = SlateTextStyle(
        size: 11,
        weight: .semibold,
        relativeTo: .caption2,
        tracking: 0.4
    )

    // MARK: - Echelle generale (design/tokens.md §9)

    /// Titre de note (editeur). 28 pt Bold.
    public static let titleNote = SlateTextStyle(size: 28, weight: .bold, relativeTo: .largeTitle)

    /// Titre secondaire. 22 pt Bold.
    public static let titleSecondary = SlateTextStyle(size: 22, weight: .bold, relativeTo: .title2)

    /// Sous-titre. 17 pt Regular.
    public static let subtitle = SlateTextStyle(size: 17, weight: .regular, relativeTo: .headline)

    /// Titre de niveau 4 (`h4`, design/tokens.md §9). 17 pt Semibold. Ajoute en Phase 5
    /// pour combler le gap signale par l'agent 5.1 : `HeadingStyle` (SlateEditor)
    /// retombait sur `bodyEmphasis` pour les niveaux 4 a 6, faute de token dedie -- la
    /// spec definit bien les 6 niveaux, ce token les rend enfin distinguables entre eux.
    public static let h4 = SlateTextStyle(size: 17, weight: .semibold, relativeTo: .headline)

    /// Titre de niveau 5 (`h5`, design/tokens.md §9). 15 pt Semibold. Voir `h4`.
    public static let h5 = SlateTextStyle(size: 15, weight: .semibold, relativeTo: .body)

    /// Titre de niveau 6 (`h6`, design/tokens.md §9). 13 pt Semibold. Voir `h4`.
    public static let h6 = SlateTextStyle(size: 13, weight: .semibold, relativeTo: .footnote)

    /// Corps de texte. 15 pt Regular.
    public static let body = SlateTextStyle(size: 15, weight: .regular, relativeTo: .body)

    /// Corps de texte accentue. 15 pt Semibold.
    public static let bodyEmphasis = SlateTextStyle(size: 15, weight: .semibold, relativeTo: .body)

    /// Legende / metadonnee. 12 pt Regular.
    public static let caption = SlateTextStyle(size: 12, weight: .regular, relativeTo: .caption)

    /// Libelle d'UI / bouton. 13 pt Regular.
    public static let label = SlateTextStyle(size: 13, weight: .regular, relativeTo: .callout)

    /// Titre de cellule dans la liste de notes. 14 pt Semibold.
    public static let listTitle = SlateTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline)

    /// Extrait de note dans la liste. 13 pt Regular.
    public static let listSnippet = SlateTextStyle(size: 13, weight: .regular, relativeTo: .footnote)

    // MARK: - Liste de notes (spec E3)

    /// En-tete de regroupement par date ("Aujourd'hui", "Hier"...). 13 pt Semibold.
    public static let listDateHeader = SlateTextStyle(size: 13, weight: .semibold, relativeTo: .subheadline)
}

/// Applique un `SlateTextStyle` via `@ScaledMetric`, pour que la taille de base suive le
/// Dynamic Type systeme plutot que de rester figee.
private struct SlateFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight
    private let tabularNums: Bool
    private let tracking: CGFloat

    init(style: SlateTextStyle) {
        _scaledSize = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
        weight = style.weight
        tabularNums = style.tabularNums
        tracking = style.tracking
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: scaledSize, weight: weight))
            .tracking(tracking)
            .modifier(TabularNumsModifier(isEnabled: tabularNums))
    }
}

/// Applique `.monospacedDigit()` conditionnellement, en un seul point, pour eviter un
/// `if/else` dupliquant l'arbre de vues dans `SlateFontModifier`.
private struct TabularNumsModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.monospacedDigit()
        } else {
            content
        }
    }
}

public extension View {
    /// Applique un token `SlateFont` (taille, poids, mise a l'echelle Dynamic Type,
    /// chiffres tabulaires, tracking).
    func slateFont(_ style: SlateTextStyle) -> some View {
        modifier(SlateFontModifier(style: style))
    }

    /// Dimensionne un glyphe symbolique (`Image(systemName:)`) a partir d'une taille de
    /// base en points, mise a l'echelle par Dynamic Type via `@ScaledMetric`.
    ///
    /// **Facon UNIQUE de dimensionner un glyphe dans Slate.** Un `CGFloat` seul (voir les
    /// tokens `SlateGeometry.sidebarIconSize`, `workspaceIconSize`, `toolbarIconSize`...)
    /// ne suit PAS le Dynamic Type tant qu'il n'est pas passe par ce modificateur -- la
    /// spec E2 l'exige explicitement pour "toutes les tailles". Ne jamais ecrire
    /// `.font(.system(size:))` directement sur une icone : toujours
    /// `.slateIconFont(SlateGeometry.xxxSize)`.
    ///
    /// `relativeTo` doit correspondre au style de texte le plus proche visuellement de
    /// l'icone (ex: `.subheadline` pour une icone accolee a `SlateFont.sidebarItem`),
    /// pour que l'icone grossisse au meme rythme que le texte qu'elle accompagne.
    func slateIconFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(SlateIconFontModifier(size: size, weight: weight, relativeTo: textStyle))
    }
}

/// Mise a l'echelle Dynamic Type d'un glyphe symbolique dimensionne en points bruts.
/// Pendant de `SlateFontModifier`, mais sans les options propres au texte (chiffres
/// tabulaires, tracking) qui n'ont pas de sens sur une `Image(systemName:)`.
private struct SlateIconFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight))
    }
}

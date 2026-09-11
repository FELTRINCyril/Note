import SwiftUI

/// Metriques des blocs "decores" (citation, callout, code, tableau, divider, listes,
/// colonnes) : design/tokens.md §16 (metriques ajoutees, Phase 8, artboards E-H de
/// `Slate P1 - Formatage & blocs.dc.html`).
///
/// Etend `SlateGeometry` plutot que d'introduire un second namespace, comme le reste de
/// l'editeur (`EditorGeometry.swift`).
public extension SlateGeometry {
    /// Marge verticale d'un bloc decore (citation, callout, code, tableau, divider),
    /// AU LIEU des 4 pt de `editorBlockSpacing` (reserve aux paragraphes). Artboard F/G :
    /// "8 pt au-dessus et en dessous". Egal a `Spacing.sm` : alias nomme, pas une nouvelle
    /// valeur.
    static let decoratedBlockSpacing: CGFloat = Spacing.sm

    /// Largeur de la colonne de marqueur d'un item de liste (puce, numero). Artboard G :
    /// "18 pt", la meme valeur que `blockHandleSize` (poignee de chrome) mais un token
    /// DISTINCT : les deux widgets n'ont rien en commun semantiquement, leur egalite
    /// numerique est une coincidence de la maquette. Alias explicite pour ne pas
    /// reintroduire le litteral `18`.
    static let listMarkerWidth: CGFloat = blockHandleSize

    /// Diametre visuel de la case a cocher d'un item de liste. Equivalent `checkbox.size`
    /// (design/tokens.md §15). Distinct de `listMarkerWidth`/`blockHandleSize` malgre la
    /// meme valeur (18 pt) : §15 le documente comme un token a part entiere.
    static let checklistCheckboxSize: CGFloat = 18

    /// Cible de clic d'une case a cocher, plus grande que le glyphe dessine. Artboard G :
    /// "cases 18 pt, cible de clic etendue a 28 pt".
    static let checklistCheckboxHitSize: CGFloat = 28

    /// Largeur de la barre laterale d'un bloc de citation. Artboard F : "barre
    /// quote.barColor de 3 pt".
    static let quoteBarWidth: CGFloat = 3

    /// Hauteur de la cible de selection d'un bloc separateur (le trait lui-meme reste
    /// `strokeHairline`). Artboard G : "cible de selection de 24 pt de haut". Egal a
    /// `Spacing.xl` : alias nomme, pas une nouvelle valeur.
    static let dividerHitHeight: CGFloat = Spacing.xl

    // MARK: - Colonnes (artboard J, geometrie reservee a la Phase 10)

    /// Espace entre deux colonnes. Equivalent `column.gap` (design/tokens.md §16). Egal a
    /// `Spacing.xl` : alias nomme, pas une nouvelle valeur.
    static let columnGap: CGFloat = Spacing.xl

    /// Largeur minimale d'une colonne, en dessous de laquelle elle ne peut plus retrecir.
    /// Artboard J : "Largeur minimale d'une colonne : 120 pt".
    static let columnMinWidth: CGFloat = 120

    /// Nombre maximal de colonnes. Artboard J : "Maximum 4 colonnes".
    static let columnMaxCount = 4

    /// Largeur de colonne de texte en dessous de laquelle les colonnes s'empilent dans
    /// l'ordre de lecture (artboard J : "sous 560 pt", quelle que soit la largeur de
    /// fenetre). La meme bascule s'applique a `.accessibility1` et au-dela, independamment
    /// de cette largeur.
    static let columnStackThreshold: CGFloat = 560

    /// Largeur de la poignee de separateur de colonnes au survol/saisie (invisible au
    /// repos, ou seul `strokeHairline` est trace). Artboard J : "4 pt de large au survol".
    static let columnResizerWidth: CGFloat = 4

    /// Glyphe d'icone de callout. Equivalent `icon.m` (design/tokens.md §15, 16 pt),
    /// artboard F : "icone 16 pt". Pas de namespace `icon.s/m/l` generique dans
    /// `SlateGeometry` (chaque contexte nomme sa propre constante, meme convention que
    /// `sidebarIconSize`/`toolbarIconSize`) : ce token est le nom propre a ce contexte.
    static let calloutIconSize: CGFloat = 16
}

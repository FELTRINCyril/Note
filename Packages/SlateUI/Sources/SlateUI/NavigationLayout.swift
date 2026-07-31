import SwiftUI

/// Largeur d'une colonne de `NavigationSplitView`, exprimee comme une plage.
///
/// Type dedie plutot qu'un tuple `(min, ideal, max)` : nommage explicite a l'appel, et
/// une seule source de verite si la contrainte evolue (ex: ajout d'une largeur par
/// defaut distincte de `ideal` en Phase 13).
public struct ColumnWidth: Sendable, Equatable {
    public let min: CGFloat
    public let ideal: CGFloat
    public let max: CGFloat

    public init(min: CGFloat, ideal: CGFloat, max: CGFloat) {
        self.min = min
        self.ideal = ideal
        self.max = max
    }
}

/// Tokens de largeur des colonnes du `NavigationSplitView` a 3 colonnes
/// (sidebar | liste | detail), voir docs/00_architecture.md §Patterns.
///
/// Valeurs alignees en Phase 3 sur `design/03_sidebar/Slate_E1-E2_coquille-sidebar.html`
/// ("Specifications E1") : sidebar min 180 / ideal 240 / max 320, liste min 260 /
/// ideal 300 / max 420. La fenetre minimale visee est 1000 x 700.
public enum NavigationLayout {
    /// Largeur de la colonne sidebar.
    public static let sidebarWidth = ColumnWidth(min: 180, ideal: 240, max: 320)

    /// Largeur de la colonne liste de notes.
    public static let listWidth = ColumnWidth(min: 260, ideal: 300, max: 420)

    /// Largeur minimale pratique de la colonne editeur. Ne pilote pas
    /// `navigationSplitViewColumnWidth` : le detail occupe le reste de la fenetre sans
    /// `ideal`/`max` explicites. Sert de repere pour la largeur minimale de fenetre
    /// (sidebar 180 + liste 260 + editeur 480 ~ fenetre 1000 x 700 minimale de la spec).
    public static let editorMinWidth: CGFloat = 480

    /// Largeur maximale de la colonne de texte a l'interieur de l'editeur. C'est ce
    /// token, pas une largeur de colonne `NavigationSplitView`, qui garantit la
    /// respiration de lecture ("editor.maxContentWidth" de `design/tokens.md` §16).
    /// Alias de `SlateGeometry.editorMaxContentWidth`, expose ici aussi car c'est un
    /// token de mise en page de premier niveau au meme titre que les largeurs de colonne.
    public static let editorMaxContentWidth = SlateGeometry.editorMaxContentWidth
}

public extension View {
    /// Applique un token de largeur a une colonne de `NavigationSplitView`.
    ///
    /// Evite de repeter `min:/ideal:/max:` a chaque appel et garantit que les trois
    /// bornes proviennent bien du meme token.
    func slateColumnWidth(_ width: ColumnWidth) -> some View {
        navigationSplitViewColumnWidth(min: width.min, ideal: width.ideal, max: width.max)
    }
}

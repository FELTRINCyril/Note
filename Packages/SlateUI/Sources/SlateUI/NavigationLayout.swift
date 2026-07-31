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
/// Ces valeurs ne sont pas encore specifiees dans `design/tokens.md` (qui ne couvre
/// pas les largeurs de colonnes de premier niveau, seulement `column.gap` pour les
/// colonnes internes a l'editeur). Elles sont posees ici en Phase 1 pour eviter toute
/// valeur numerique en dur dans `App/RootView.swift`, et seront alignees sur
/// `design/tokens.md` si Claude Design en propose une version en Phase 13.
public enum NavigationLayout {
    /// Largeur de la colonne sidebar.
    public static let sidebarWidth = ColumnWidth(min: 180, ideal: 220, max: 280)

    /// Largeur de la colonne liste de notes.
    public static let listWidth = ColumnWidth(min: 240, ideal: 300, max: 400)
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

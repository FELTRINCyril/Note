import SwiftUI

/// Tokens de largeur des colonnes du `NavigationSplitView` a 3 colonnes
/// (sidebar | liste | detail), voir docs/00_architecture.md §Patterns.
///
/// Ces valeurs ne sont pas encore specifiees dans `design/tokens.md` (qui ne couvre
/// pas les largeurs de colonnes de premier niveau, seulement `column.gap` pour les
/// colonnes internes a l'editeur). Elles sont posees ici en Phase 1 pour eviter toute
/// valeur numerique en dur dans `App/RootView.swift`, et seront alignees sur
/// `design/tokens.md` si Claude Design en propose une version en Phase 13.
public enum NavigationLayout {
    /// Largeur de la colonne sidebar (min/ideal/max).
    public static let sidebarWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (180, 220, 280)

    /// Largeur de la colonne liste (min/ideal/max).
    public static let listWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (240, 300, 400)
}

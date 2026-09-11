import SwiftUI

// Premier plan a poser sur l'aplat d'accent de selection (`accentSelectionFill`).
//
// Extrait de `SlateColor.swift` pour tenir la limite `file_length` de SwiftLint (meme
// demarche que `SlateSemanticColors.swift`, voir sa note en tete de fichier).

extension SlateColor {
    /// Couleur de premier plan a utiliser pour TOUT contenu (icone, glyphe, texte) pose
    /// sur `accentSelectionFill` (= la pastille de selection active). Alias de
    /// `textOnAccent` sous un nom generique : ce token ne parle pas que de texte, il sert
    /// aussi aux icones (chevron, icone de dossier, etoile de favori...) qui doivent
    /// suivre la meme regle (spec E2, icone de dossier : "teinte = couleur du dossier ;
    /// passe en blanc sur selection active"). Voir `foreground(_:onAccentFill:)` pour la
    /// facon recommandee de le consommer depuis un composant.
    public static var foregroundOnAccentFill: Color { textOnAccent }

    /// Choisit entre `base` et `foregroundOnAccentFill` selon que le contenu est
    /// actuellement pose sur l'aplat d'accent de selection (`EnvironmentValues.slateIsOnAccentFill`).
    ///
    /// Point d'entree unique recommande pour tout composant qui doit rester lisible a la
    /// fois hors selection (sa teinte habituelle, `base`) et sur la selection active
    /// (bascule automatique en blanc/`text.onAccent`). Exemple :
    /// ```swift
    /// @Environment(\.slateIsOnAccentFill) private var isOnAccentFill
    /// ...
    /// .foregroundStyle(SlateColor.foreground(SlateColor.textTertiary, onAccentFill: isOnAccentFill))
    /// ```
    public static func foreground(_ base: Color, onAccentFill isOnAccentFill: Bool) -> Color {
        isOnAccentFill ? foregroundOnAccentFill : base
    }

    /// Premier plan SECONDAIRE a utiliser sur `accentSelectionFill` (spec E3 : l'extrait
    /// de la cellule de note, "blanc 95%"). Distinct de `foregroundOnAccentFill` (le
    /// premier plan PRINCIPAL, blanc opaque) : la spec cree une hierarchie a deux niveaux
    /// sur la selection, et c'est CE token, le plus exigeant des deux, qui contraint le
    /// calcul de `accentSelectionFill` (voir `SlateAccent.selectionForegroundSecondary`).
    public static let foregroundSecondaryOnAccentFill = Color.white.opacity(0.95)

    /// Choisit entre `base` et `foregroundSecondaryOnAccentFill` selon
    /// `EnvironmentValues.slateIsOnAccentFill`. Pendant de `foreground(_:onAccentFill:)`
    /// pour le contenu SECONDAIRE (extrait, metadonnee) plutot que principal (titre).
    public static func foregroundSecondary(_ base: Color, onAccentFill isOnAccentFill: Bool) -> Color {
        isOnAccentFill ? foregroundSecondaryOnAccentFill : base
    }
}

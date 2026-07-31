import SwiftUI

/// Valeur d'environnement generique : vrai quand la vue est actuellement posee sur
/// l'aplat PLEIN d'accent de selection (`SlateColor.accentSelectionFill`), faux sinon.
///
/// ## Pourquoi cette valeur existe
/// `SidebarRow` (ligne selectionnee, fenetre active) peint son fond avec
/// `accentSelectionFill`. Tout contenu pose par-dessus (libelle, compteur, chevron,
/// icone de dossier, etoile de favori...) doit alors basculer sur une couleur de
/// premier plan qui respecte l'AA SUR CET APLAT PRECIS -- pas sur `bgSidebarOpaque`.
/// Le libelle le faisait deja explicitement (`SidebarRow.labelColor`) ; `SidebarCounter`
/// et `DisclosureChevron`, eux, gardaient `text.tertiary` (26% d'opacite noir/blanc) en
/// toutes circonstances, ce qui tombe a ~1,5:1 une fois compose sur l'aplat bleu -- tres
/// loin du seuil AA de 4,5:1. Voir `WCAGContrast.compositeOverBackground` et
/// `ContrastRatioTests` pour la demonstration chiffree.
///
/// Plutot que corriger ce point composant par composant (le meme probleme reviendra en
/// Phase 4 avec les icones "verrouillee"/"epinglee" de la liste de notes, et dans
/// `SlateFeatures` avec l'icone de dossier et l'etoile de favori -- spec E2 : "teinte =
/// couleur du dossier ; passe en blanc sur selection active"), cette valeur
/// d'environnement centralise la question "suis-je sur l'aplat d'accent ?" en un seul
/// endroit. `SidebarRow` est la seule vue qui l'ecrit (elle seule sait si sa ligne est
/// selectionnee ET la fenetre au premier plan -- cf. `isSelectedInActiveWindow`) ; tout
/// composant descendant, dans `SlateUI` comme dans `SlateFeatures`, peut la lire pour
/// choisir sa couleur via `SlateColor.foreground(_:onAccentFill:)`.
///
/// Volontairement faux quand la ligne est selectionnee mais la fenetre INACTIVE : le
/// fond bascule alors sur `state.selectedInactive`, un gris neutre a faible opacite, pas
/// sur l'aplat d'accent -- `text.tertiary` y reste parfaitement lisible.
public extension EnvironmentValues {
    @Entry var slateIsOnAccentFill: Bool = false
}

import SwiftUI

/// Etat visuel d'un bloc dans `BlockContainer` (spec E4, "GALERIE D'ETATS" et
/// "Accessibilite" : "Focus != selection - contour pour la navigation clavier, aplat
/// pour la selection de contenu : discernables sans couleur").
///
/// `SlateUI` ne connait ni `Block` ni `Note` (voir CLAUDE.md §4) : cet enum decrit
/// uniquement l'apparence a peindre, pas la logique qui la produit -- c'est a
/// `SlateEditor`/`SlateFeatures` de calculer, pour un bloc donne, lequel de ces cas
/// s'applique (focus d'edition, selection multi-blocs, focus clavier de navigation...).
public enum SlateBlockState: Equatable, Sendable {
    /// Repos : aucun chrome, aucun aplat.
    case normal
    /// La souris est dans la zone du bloc : chrome visible, pas d'aplat.
    case hovered
    /// Edition : le caret est dans ce bloc. Chrome visible.
    case focused
    /// Bloc (ou plage de blocs) selectionne en entier (Echap, Cmd+A, clic sur la
    /// poignee) -> aplat `SlateColor.blockSelectedBackground`.
    case selected
    /// Focus clavier de NAVIGATION (Tab / VoiceOver) -- distinct de `.selected` :
    /// contour `SlateColor.focusRing` + lisere opaque, jamais d'aplat (voir
    /// `BlockContainer.focusRing`).
    case keyboardFocused

    /// Le chrome de bloc (poignee + bouton d'insertion) doit-il rester visible meme
    /// hors survol de la souris ?
    public var showsChrome: Bool {
        self == .hovered || self == .focused || self == .selected || self == .keyboardFocused
    }

    /// Cet etat peint-il l'aplat de selection ?
    public var showsSelectionFill: Bool { self == .selected }

    /// Cet etat peint-il le contour de focus clavier ?
    public var showsFocusRing: Bool { self == .keyboardFocused }
}

/// Position d'un bloc dans une plage de selection multi-blocs contigus, pour arrondir
/// l'aplat de selection SEULEMENT aux extremites de la plage (spec E4 : "l'aplat doit
/// etre continu, coins arrondis seulement aux extremites de la plage, les 4 pt
/// intermediaires combles").
///
/// La selection multi-blocs elle-meme arrive en sous-etape 5.6 ; cette API existe deja
/// pour que `BlockContainer` n'ait pas besoin d'evoluer quand elle sera branchee.
public enum SlateBlockRangePosition: Equatable, Sendable {
    /// Bloc seul selectionne : arrondi sur les 4 coins.
    case single
    /// Premier bloc d'une plage de 2+ blocs : arrondi seulement en haut.
    case first
    /// Bloc au milieu d'une plage de 3+ blocs : aucun arrondi, l'aplat se prolonge sur
    /// toute sa hauteur.
    case middle
    /// Dernier bloc d'une plage de 2+ blocs : arrondi seulement en bas.
    case last

    /// Rayon du coin superieur de l'aplat, pour ce cas.
    public var topRadius: CGFloat { self == .single || self == .first ? SlateGeometry.radiusMedium : 0 }

    /// Rayon du coin inferieur de l'aplat, pour ce cas.
    public var bottomRadius: CGFloat { self == .single || self == .last ? SlateGeometry.radiusMedium : 0 }

    /// L'aplat doit-il se prolonger vers le BAS pour combler le `blockSpacing` avec le
    /// bloc suivant de la meme plage (sinon un trou de 4 pt casserait la continuite) ?
    public var extendsDown: Bool { self == .first || self == .middle }
}

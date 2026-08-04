import SwiftUI

/// Echelle d'espacement de Slate (4pt), alignee sur `design/tokens.md` §10.
///
/// Phase 1 : seuls les paliers principaux etaient exposes (xs/sm/md/lg/xl). Phase 5
/// (E4) ajoute `xxl` (32pt = `space.2xl`), necessaire a la respiration verticale de
/// l'editeur (haut de colonne sans couverture, chevauchement de l'icone). `3xl` (48pt)
/// reste absent : rien n'en a encore besoin -- la gouttiere de l'editeur (48pt) se
/// derive explicitement de `handle.size`/`xs`/`sm`, pas de ce palier.
/// Aucune vue ne doit ecrire une valeur d'espacement en dur : toujours passer par ce type.
public enum Spacing {
    /// 4pt - equivalent `space.xs` de `design/tokens.md`.
    public static let xs: CGFloat = 4

    /// 8pt - equivalent `space.s`.
    public static let sm: CGFloat = 8

    /// 12pt - equivalent `space.m`.
    public static let md: CGFloat = 12

    /// 16pt - equivalent `space.l`.
    public static let lg: CGFloat = 16

    /// 24pt - equivalent `space.xl`.
    public static let xl: CGFloat = 24

    /// 32pt - equivalent `space.2xl`. Ajoute en Phase 5 (E4) : haut de colonne editeur
    /// sans couverture, chevauchement de l'icone sur la couverture.
    public static let xxl: CGFloat = 32
}

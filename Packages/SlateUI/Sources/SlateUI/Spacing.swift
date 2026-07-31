import SwiftUI

/// Echelle d'espacement de Slate (4pt), alignee sur `design/tokens.md` §10.
///
/// Phase 1 : seuls les paliers principaux sont exposes (xs/sm/md/lg/xl). Les paliers
/// plus fins (`2xs`, `2xl`, `3xl`) seront ajoutes quand un ecran en aura besoin.
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
}

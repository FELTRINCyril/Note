import SwiftUI

/// Tokens de geometrie (rayons, tailles, zones cliquables) alignes sur
/// `design/tokens.md` §11/§12/§15 et sur la spec E2 ("Specifications E2").
///
/// Comme pour `Spacing`, aucune vue ne doit ecrire une de ces valeurs en dur.
public enum SlateGeometry {
    // MARK: - Rayons de coin (design/tokens.md §11)

    /// Champs, petits boutons, lignes de sidebar. Equivalent `radius.s`.
    public static let radiusSmall: CGFloat = 6

    /// Cartes, blocs. Equivalent `radius.m`.
    public static let radiusMedium: CGFloat = 8

    /// Popovers, modales. Equivalent `radius.l`.
    public static let radiusLarge: CGFloat = 12

    // MARK: - Focus (design/tokens.md §12)

    /// Epaisseur de l'anneau de focus clavier. Equivalent `focusRing.width`.
    public static let focusRingWidth: CGFloat = 3

    /// Decalage de l'anneau de focus par rapport aux bords de la ligne. Equivalent `focusRing.offset`.
    public static let focusRingOffset: CGFloat = 1

    // MARK: - Barre laterale (spec E2 "Specifications E2")

    /// Hauteur MINIMALE d'une ligne de sidebar : elle s'etire en Dynamic Type, ce n'est
    /// pas une hauteur fixe. Equivalent `row.height.sidebar`.
    public static let sidebarRowMinHeight: CGFloat = 28

    /// Marge laterale entre le bord de la colonne et la pastille de selection.
    public static let sidebarGutter: CGFloat = 8

    /// Indentation appliquee au CONTENU par niveau de profondeur (la pastille de
    /// selection reste pleine largeur). Equivalent `sidebar.indent.step`.
    public static let sidebarIndentStep: CGFloat = 16

    /// Taille visuelle du glyphe de chevron.
    public static let sidebarChevronSize: CGFloat = 10

    /// Zone cliquable du chevron, plus large que le glyphe pour rester distincte du
    /// reste de la ligne.
    public static let sidebarChevronHitArea: CGFloat = 14

    /// Hauteur du pied de sidebar (Reglages / Corbeille / nouveau dossier / nouvelle note).
    public static let sidebarFooterHeight: CGFloat = 40

    /// Icone de dossier dans une ligne de sidebar. Spec E2 : "Icone 14 pt".
    public static let sidebarIconSize: CGFloat = 14

    /// Glyphe du menu contextuel ("...") d'une ligne de sidebar.
    public static let sidebarMenuGlyphSize: CGFloat = 12

    /// Etoile de favori affichee dans une ligne de sidebar.
    public static let sidebarBadgeIconSize: CGFloat = 11

    // MARK: - Selecteur de workspace

    /// Icone du selecteur de workspace.
    public static let workspaceIconSize: CGFloat = 13

    /// Chevron du selecteur de workspace. Spec : "Chevron 10 pt".
    public static let workspaceChevronSize: CGFloat = 10

    // MARK: - Barre d'outils

    /// Icone d'etat de synchronisation en barre d'outils.
    public static let toolbarIconSize: CGFloat = 13

    // MARK: - Feuille de choix d'icone

    /// Glyphe affiche dans une case de la feuille de choix d'icone.
    public static let pickerGlyphSize: CGFloat = 18

    /// Cible tactile/cliquable d'une case de la feuille de choix d'icone.
    public static let pickerHitTarget: CGFloat = 44

    // MARK: - Editeur

    /// Largeur maximale de la colonne de texte dans l'editeur. Equivalent `editor.maxContentWidth`.
    public static let editorMaxContentWidth: CGFloat = 720
}

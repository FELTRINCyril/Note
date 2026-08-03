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
    /// Utilise par `SidebarRow` : l'anneau grossit VERS L'EXTERIEUR de la forme (spec E2 :
    /// "focusRing 3 pt, offset 1"). NE PAS confondre avec `noteCellFocusRingInset`
    /// ci-dessous : la spec E3 demande une geometrie differente pour la cellule de note
    /// (anneau EN INSET, donc vers l'interieur).
    public static let focusRingOffset: CGFloat = 1

    /// Epaisseur des filets fins (separateurs, traits). Equivalent `stroke.hairline`
    /// (design/tokens.md §12 : "1 (0,5 sur ecran Retina)"). La reduction a 0,5 sur Retina
    /// est laissee a l'appelant (ex: `/ displayScale`) : ce token porte la valeur nominale
    /// en points, pas la resolution ecran.
    public static let strokeHairline: CGFloat = 1

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

    // MARK: - Liste de notes (spec E3 "Specifications E3")

    /// Hauteur MINIMALE d'une cellule de note (titre + extrait + date) : elle s'etire en
    /// Dynamic Type, ce n'est pas une hauteur fixe. Equivalent `row.height.noteCell`.
    public static let noteCellMinHeight: CGFloat = 64

    /// Padding horizontal de la cellule de note. Spec E3 : "padding 14 / 10".
    public static let noteCellPaddingHorizontal: CGFloat = 14

    /// Padding vertical de la cellule de note. Spec E3 : "padding 14 / 10".
    public static let noteCellPaddingVertical: CGFloat = 10

    /// Taille des glyphes d'indicateurs (epingle/verrouille/favori) avant le titre.
    /// Spec E3 : "indicateurs 11 pt".
    public static let noteCellIndicatorIconSize: CGFloat = 11

    /// Decalage EN INSET (vers l'interieur) de l'anneau de focus d'une cellule de note.
    /// Spec E3 : "focus clavier = anneau 3 pt accent.focusRing en inset". Geometrie
    /// DIFFERENTE de `focusRingOffset` (sidebar, anneau vers l'exterieur) : deriver la
    /// moitie de `focusRingWidth` garde l'anneau entierement a l'interieur des bords de
    /// la cellule (le trait, centre sur le rectangle retreci de cette valeur, affleure
    /// exactement le bord exterieur sans le depasser).
    public static let noteCellFocusRingInset: CGFloat = focusRingWidth / 2

    /// Hauteur du champ de recherche. Spec E3 : "champ 22 pt".
    public static let searchFieldHeight: CGFloat = 22

    /// Rayon de coin du champ de recherche. Spec E3 : "rayon 6" (= `radiusSmall`, alias
    /// nomme pour la tracabilite avec la spec).
    public static let searchFieldRadius: CGFloat = radiusSmall

    /// Icone de loupe / bouton d'effacement du champ de recherche. La spec E3 ne donne
    /// pas de taille explicite pour cette icone ; on reprend `icon.s` (design/tokens.md
    /// §15, 14 pt), coherent avec les autres glyphes 14 pt de la coquille.
    public static let searchFieldIconSize: CGFloat = 14
}

import SwiftUI

/// Metriques des blocs media (image, fichier joint) : design/tokens.md §16 quater,
/// artboards A/B/C de `Slate P2 - Medias & pieces jointes.dc.html` (Phase 9).
///
/// Etend `SlateGeometry` plutot que d'introduire un second namespace, comme le reste de
/// l'editeur (`EditorGeometry.swift`, `BlockDecorationMetrics.swift`).
public extension SlateGeometry {
    // MARK: - Zone de depot d'image (artboard A)

    /// Hauteur de la zone de depot vide, dans ses deux etats (repos, survol de depot).
    /// Artboard A : "La zone vide fait 80 pt de haut, pas plus : elle ne doit pas donner
    /// l'impression d'un trou dans la note."
    static let mediaDropzoneHeight: CGFloat = 80

    /// Epaisseur du tirete au repos. Design/tokens.md §16 quater, `media.dropzone.border`
    /// : "Tirete 1 pt au repos".
    static let mediaDropzoneBorderWidth: CGFloat = strokeHairline

    /// Epaisseur du tirete pendant un survol de depot. Design/tokens.md §16 quater,
    /// `media.dropzone.active.bg` : "tirete 2 pt en accent.default".
    static let mediaDropzoneActiveBorderWidth: CGFloat = 2

    /// Hauteur de la barre de progression de `MediaUploadProgressView` (artboard A :
    /// "height:4px"), doublee par le texte -- jamais la seule information de progres.
    static let mediaUploadProgressBarHeight: CGFloat = 4

    // MARK: - Paliers de largeur d'image (artboard A, "Trois largeurs, pas un curseur libre")

    /// Largeur de la colonne de texte (palier "Colonne"). Alias de `editorMaxContentWidth`
    /// (720 pt) : meme valeur, pas un nouveau token -- reutilise tel quel.
    static let mediaColumnWidth: CGFloat = editorMaxContentWidth

    /// Palier "debord", entre la colonne (720 pt) et la pleine largeur. Equivalent
    /// `media.overflowWidth` (design/tokens.md §16 quater).
    static let mediaOverflowWidth: CGFloat = 960

    // MARK: - Poignees de redimensionnement (artboard A : "poignees 8 x 28 pt, cible 20 pt")

    /// Largeur visuelle d'une poignee de redimensionnement d'image.
    static let mediaHandleWidth: CGFloat = 8

    /// Hauteur visuelle d'une poignee de redimensionnement d'image.
    static let mediaHandleHeight: CGFloat = 28

    /// Epaisseur du lisere de la poignee, en `bg.editor` (design/tokens.md §16 quater,
    /// `media.handle.fill` : "lisere 1,5 pt en bg.editor").
    static let mediaHandleBorderWidth: CGFloat = 1.5

    /// Cible de saisie d'une poignee au repos (souris). Artboard A : "cible de saisie
    /// portee a 20 pt".
    static let mediaHandleHitSize: CGFloat = 20

    /// Cible de saisie d'une poignee des `.accessibility1` (artboard D, "Dynamic Type") :
    /// la poignee GARDE sa taille visuelle 8 x 28 pt (controle direct, non textuel) mais
    /// sa cible passe a 28 pt.
    static let mediaHandleHitSizeAccessibility: CGFloat = 28

    /// Epaisseur + decalage du contour de selection d'une image (artboard A, sombre :
    /// "outline:2px solid accent; outline-offset:2px").
    static let mediaSelectionOutlineWidth: CGFloat = 2
    static let mediaSelectionOutlineOffset: CGFloat = 2

    // MARK: - Pieces jointes (artboard B)

    /// Hauteur fixe du bloc fichier joint, en dessous de `.accessibility1` (au-dela, le
    /// bloc passe en hauteur libre, voir `AttachmentRowView`). Equivalent
    /// `attachment.height` (design/tokens.md §16 quater).
    static let attachmentHeight: CGFloat = 52

    /// Taille de la pastille d'icone de type de fichier. Equivalent `attachment.icon.size`
    /// (design/tokens.md §16 quater).
    static let attachmentIconSize: CGFloat = 32

    /// Rayon de coin de la pastille d'icone. Design/tokens.md §16 quater,
    /// `attachment.icon.size` : "Pastille de type, rayon `radius.s`" -- alias, pas une
    /// nouvelle valeur.
    static let attachmentIconRadius: CGFloat = radiusSmall

    /// Taille des boutons d'action revelees au survol (Apercu, Telecharger, menu).
    /// Artboard B : boutons 28 x 28 pt. Egal a `checklistCheckboxHitSize` : coincidence
    /// numerique, pas une parente semantique (meme convention que `listMarkerWidth`).
    static let attachmentActionButtonSize: CGFloat = checklistCheckboxHitSize

    /// Taille du glyphe dessine dans un bouton d'action de piece jointe (artboard B :
    /// glyphes 14 x 14 pt).
    static let attachmentActionIconSize: CGFloat = 14

    // MARK: - Controles pilules reutilisables (barre d'alignement, badges de depot)

    /// Hauteur des controles "pilule" (barre d'alignement, badge de palier, badge de
    /// comptage de depot). Egal a `searchFieldHeight` (22 pt) : coincidence numerique
    /// avec `control.height.s` (design/tokens.md §15), pas une parente semantique.
    static let mediaPillControlHeight: CGFloat = searchFieldHeight

    /// Taille des glyphes dans les controles pilule (coche, icone de menu...).
    static let mediaPillGlyphSize: CGFloat = 11

    // MARK: - Depot dans l'editeur (artboard C)

    /// Diametre du point marquant l'origine de la ligne d'insertion de depot.
    static let mediaDropIndicatorDotSize: CGFloat = 8
}

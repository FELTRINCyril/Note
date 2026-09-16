import SwiftUI

/// Metriques specifiques aux bases de donnees (design/tokens.md §18, Phase 17). Etend
/// `SlateGeometry` plutot que d'introduire un second namespace, meme convention que
/// `BlockDecorationMetrics.swift`/`EditorGeometry.swift`.
public extension SlateGeometry {
    // MARK: - Ombre de carte (`db.card.shadow` = `elevation.low`)

    /// Rayon de flou de `elevation.low` (design/tokens.md §13 : "blur:3").
    static let databaseCardShadowRadius: CGFloat = 3

    /// Decalage vertical de `elevation.low` (design/tokens.md §13 : "y:1").
    static let databaseCardShadowY: CGFloat = 1

    // MARK: - Grille (colonnes)

    /// Hauteur de la ligne d'en-tete de colonne (artboard A : barre 44 pt de haut,
    /// ligne d'en-tete elle-meme mesuree a 7 pt de padding vertical + texte 13 pt).
    static let databaseColumnHeaderHeight: CGFloat = 32

    /// Largeur minimale d'une colonne de grille en dessous de laquelle elle ne peut plus
    /// retrecir. Alias de `columnMinWidth` (Phase 10, colonnes de l'editeur) : meme
    /// contrainte, contexte different -- pas une nouvelle valeur.
    static let databaseColumnMinWidth: CGFloat = columnMinWidth

    /// Largeur de la poignee de redimensionnement de colonne. Alias de
    /// `columnResizerWidth` (Phase 10) : meme comportement visuel (invisible au repos,
    /// 4 pt actif) que le redimensionneur de colonnes de l'editeur.
    static let databaseColumnResizerWidth: CGFloat = columnResizerWidth

    // MARK: - Cellules

    /// Diametre d'un avatar de personne dans une cellule de grille/liste/galerie.
    static let databaseAvatarSize: CGFloat = 18

    /// Diametre d'un avatar de personne dans une carte Kanban (plus petite, artboard B).
    static let databaseAvatarSizeCompact: CGFloat = 16

    /// Hauteur d'une pastille de statut/etiquette (grille, liste, galerie).
    static let databaseTagPillHeight: CGFloat = 20

    /// Hauteur d'une pastille de statut/etiquette dans une carte Kanban ou un template
    /// (plus petite, artboards B/D).
    static let databaseTagPillHeightCompact: CGFloat = 18

    /// Taille de la puce carree/ronde d'un statut (artboard A : "7px x 7px").
    static let databaseStatusBulletSize: CGFloat = 7

    /// Hauteur de la barre de progression (Avancement). Artboard A : "4px".
    static let databaseProgressBarHeight: CGFloat = 4

    // MARK: - Vue Liste

    /// Hauteur d'une ligne compacte de la vue Liste. Artboard C : "34 pt en Liste contre
    /// 64 pt dans la liste de notes" -- volontairement DIFFERENT de
    /// `noteCellMinHeight`, ces deux listes n'ont pas la meme densite.
    static let databaseListRowHeight: CGFloat = 34

    /// Indentation du contenu d'une ligne de liste sous son en-tete de groupe.
    static let databaseListRowIndent: CGFloat = 16

    // MARK: - Vue Galerie

    /// Vignette petite ("S"). Artboard C : "S 96".
    static let databaseGalleryThumbnailSmall: CGFloat = 96

    /// Vignette moyenne ("M"). Artboard C : "M 160".
    static let databaseGalleryThumbnailMedium: CGFloat = 160

    /// Vignette grande ("L"). Artboard C : "L 240".
    static let databaseGalleryThumbnailLarge: CGFloat = 240

    // MARK: - Vue Calendrier

    /// Diametre de la pastille du numero de jour (aujourd'hui). Artboard B : "19px".
    static let databaseCalendarDayBadgeSize: CGFloat = 19

    /// Hauteur d'une pastille d'evenement dans une case de jour. Artboard B : "16px".
    static let databaseCalendarEventPillHeight: CGFloat = 16

    // MARK: - Kanban

    /// Largeur minimale d'une colonne Kanban.
    static let databaseKanbanColumnMinWidth: CGFloat = 220
}

import SwiftUI

/// Metriques de l'editeur de blocs (design/tokens.md §16 + spec E4, "Geometrie &
/// respiration"). Etend `SlateGeometry` plutot que d'introduire un second namespace :
/// c'est le meme contrat que `editorMaxContentWidth` (deja porte par `SlateGeometry`
/// depuis la Phase 1) suit deja.
///
/// ## Choix de mise en page retenu pour la gouttiere (arbitrage Cyril, Phase 5)
/// La spec E4 ("Principe") demande une colonne de texte a 720 pt PLEINE largeur, la
/// gouttiere de chrome (48 pt) etant "en plus, a gauche, hors des 720 pt" -- et suggere
/// idealement de la faire FLOTTER hors du flux (overlay) pour que la colonne de 720
/// reste centree OPTIQUEMENT dans la fenetre.
///
/// Une gouttiere flottante (overlay ancre au bord gauche du texte, en dehors de la
/// largeur mesuree) a ete evaluee et ECARTEE : l'editeur vit dans un panneau de
/// largeur VARIABLE (troisieme colonne d'une coquille a 3 colonnes redimensionnable).
/// Si la marge disponible a gauche du texte tombe sous 48 pt (panneau retreci), un
/// overlay flottant serait soit rogne par le `ScrollView` (chrome invisible), soit
/// deborderait sur la colonne de liste voisine si le rognage est desactive (chrome
/// visuellement casse) -- une fragilite reelle, pas hypothetique, pour un panneau
/// redimensionnable. `BlockContainer`/`EditorContentColumn` reservent donc la gouttiere
/// DANS le flux (elle fait partie de la largeur totale centree, `720 + gutter`) : la
/// colonne de texte elle-meme reste strictement 720 pt (jamais reduite a 672, cf.
/// consigne), au prix d'un decalage optique d'environ `gutter / 2` (24 pt) vers la
/// droite par rapport au centre exact de la fenetre -- l'ecart que Cyril a explicitement
/// accepte en alternative a une gouttiere flottante fragile. Voir `EditorContentColumn`
/// pour l'implementation.
public extension SlateGeometry {
    // MARK: - Chrome de bloc (poignee + bouton d'insertion)

    /// Taille visuelle de la poignee ou du bouton d'insertion. Equivalent `handle.size`
    /// (design/tokens.md §15).
    static let blockHandleSize: CGFloat = 18

    /// Zone cliquable d'un bouton de chrome de bloc, plus large que son glyphe visuel
    /// (spec E4 : "18 pt visuels, cible 24 pt").
    static let blockHandleHitAreaSize: CGFloat = 24

    /// Taille du glyphe symbolique dessine dans un bouton de chrome de bloc (a l'echelle
    /// du bouton `blockHandleSize`, pas de la cible cliquable).
    static let blockHandleGlyphSize: CGFloat = 12

    /// Gouttiere de chrome reservee a gauche de la colonne de texte, HORS des 720 pt de
    /// `editorMaxContentWidth` (spec E4 "Principe" : "la gouttiere est en plus").
    /// Formule explicite de la spec ("Geometrie & respiration") : 2 x `handle.size`
    /// (18) + `space.xs` (4) + `space.s` (8) = 48. Les 8 pt finaux (`space.s`) sont le
    /// degagement entre le chrome et le texte -- exactement `editorSelectionBleed`
    /// ci-dessous, pour que le debord de l'aplat de selection ne recouvre jamais le
    /// chrome.
    static let editorGutter: CGFloat = blockHandleSize * 2 + Spacing.xs + Spacing.sm

    // MARK: - Blocs

    /// Espace vertical entre deux blocs. Equivalent `editor.blockSpacing` (§16) : 2 pt
    /// de padding haut + 2 pt bas par bloc (spec E4), pour que l'aplat de selection
    /// d'un bloc recouvre sa propre moitie de gouttiere verticale.
    static let editorBlockSpacing: CGFloat = 4

    /// Debord horizontal de l'aplat de bloc selectionne, de part et d'autre du texte
    /// (spec E4 : "8 pt de chaque cote du texte, `space.s`"). Egal a `Spacing.sm` :
    /// alias nomme pour la tracabilite avec la spec E4, pas une nouvelle valeur.
    static let editorSelectionBleed: CGFloat = Spacing.sm

    /// Epaisseur du caret d'edition et de la ligne d'insertion de drag & drop (spec E4 :
    /// "Caret. 2 pt" / "Ligne 2 pt en `block.dropIndicator`").
    static let editorCaretWidth: CGFloat = 2

    /// Interligne du corps de texte de l'editeur (§16 : `editor.paragraphLineHeight`).
    /// Multiplicateur SANS unite (corps 15 pt x 1,5 = ligne de 22,5 pt, hauteur de
    /// reference de la poignee -- spec E4) : a appliquer via `.lineSpacing` par
    /// l'appelant, pas porte par `SlateFont.body` lui-meme (qui reste un token de taille
    /// de police, pas d'interligne).
    static let editorParagraphLineHeight: CGFloat = 1.5

    // MARK: - Respiration verticale de la colonne

    /// Haut de colonne quand la note n'a PAS de couverture (spec E4 : "Haut de colonne
    /// sans couverture : 32 pt, `space.2xl`").
    static let editorContentTopPadding: CGFloat = Spacing.xxl

    /// Espace entre l'en-tete (titre/sous-titre/meta) et le premier bloc du corps
    /// (spec E4 : "En-tete -> corps : 24 pt, `space.xl`").
    static let editorHeaderToBodySpacing: CGFloat = Spacing.xl

    /// Zone cliquable en bas de document ("ecrire a la suite" -- un clic y cree un bloc
    /// vide focalise). Spec E4 : "240 pt de zone cliquable". Ne derive d'aucun palier
    /// d'espacement existant : c'est une zone d'interaction, pas une respiration.
    static let editorContentBottomPadding: CGFloat = 240

    /// Hauteur de l'image de couverture optionnelle. Spec E4 : "Couverture 200 pt".
    static let editorCoverHeight: CGFloat = 200

    /// Taille de l'icone/emoji optionnel de la note. Spec E4 : "icone 64 pt chevauchant
    /// de 32 pt".
    static let editorIconSize: CGFloat = 64

    /// Chevauchement de l'icone sur le bas de la couverture (spec E4, meme phrase que
    /// `editorIconSize` ci-dessus). Egal a `Spacing.xxl`.
    static let editorIconOverlap: CGFloat = Spacing.xxl

    /// Hauteur du chrome haut de colonne (barre "Produit > Titre" + actions -- toolbar
    /// de l'editeur). Spec E4 : "44 pt, `control.height.l` + `space.s`" (36 + 8).
    static let editorToolbarHeight: CGFloat = 44

    // MARK: - Barre de formatage flottante (artboard P1 A, Phase 7)

    /// Hauteur de la barre. Equivalent `control.height.l` (design/tokens.md §15).
    static let formatBarHeight: CGFloat = 36

    /// Rayon de coin de la barre. Equivalent `radius.m` -- alias nomme pour la
    /// tracabilite avec l'artboard ("rayon 8 pt"), pas une nouvelle valeur.
    static let formatBarRadius: CGFloat = radiusMedium

    /// Decalage vertical de la barre au-dessus de la plage selectionnee (artboard P1 A :
    /// "ancree 8 pt au-dessus de la plage"). Equivalent `space.s` -- alias nomme, pas une
    /// nouvelle valeur.
    static let formatBarOffset: CGFloat = Spacing.sm

    /// Rayon de flou de l'ombre portee, `elevation.medium` (design/tokens.md §13 : "y:4
    /// blur:12"). Pas de namespace `SlateElevation` dedie en Phase 7 (seul consommateur
    /// actuel) : a extraire si un deuxieme composant a besoin d'une des trois elevations.
    static let formatBarShadowRadius: CGFloat = 12

    /// Decalage vertical de l'ombre portee, `elevation.medium` (design/tokens.md §13).
    static let formatBarShadowY: CGFloat = 4

    // MARK: - Depot de drag & drop

    /// Epaisseur de la ligne d'insertion affichee pendant un glisser-depose de bloc.
    /// Reutilisee TELLE QUELLE pour la ligne verticale (artboard I, "depot lateral" --
    /// une epaisseur de trait, qu'il soit trace horizontalement ou verticalement, reste
    /// le meme token).
    static let editorDropIndicatorHeight: CGFloat = 2

    // MARK: - Fantome de glisser-depose (artboard I, Phase 10)

    /// Rotation du fantome de bloc en cours de glissement. Artboard I : "rotation -1 deg".
    static let dragGhostRotationDegrees: Double = -1

    /// Rayon de flou de l'ombre portee du fantome, `elevation.high` (design/tokens.md
    /// §13 : "y:10 blur:30", usage "Modales, drag"). Meme convention que
    /// `formatBarShadowRadius`/`formatBarShadowY` (elevation.medium) : pas de namespace
    /// `SlateElevation` dedie tant qu'un seul autre consommateur (barre de formatage)
    /// existe pour l'elevation moyenne -- ici le second cas d'usage (elevation haute)
    /// justifie deja de poser les tokens a cote, sans pour autant generaliser.
    static let dragGhostShadowRadius: CGFloat = 30

    /// Decalage vertical de l'ombre portee du fantome, `elevation.high`.
    static let dragGhostShadowY: CGFloat = 10

    /// Diametre du badge de comptage affiche sur le fantome pour un glissement
    /// multi-blocs. Artboard I : "badge 20x20 pt".
    static let dragGhostBadgeSize: CGFloat = 20

    // MARK: - Listes

    /// Indentation appliquee par niveau de profondeur a une liste de l'editeur.
    /// Equivalent `editor.listIndentStep` (design/tokens.md §16, ajoute en Phase 5 pour
    /// combler le gap signale par l'agent 5.1 -- `Spacing.lg`, 16 pt, etait reutilise en
    /// attendant). Egal a `Spacing.xl` : alias nomme pour la tracabilite avec la spec,
    /// pas une nouvelle valeur.
    static let editorListIndentStep: CGFloat = Spacing.xl

    /// Diametre de la puce DESSINEE d'un item de liste a puces. Equivalent
    /// `list.bulletSize` (design/tokens.md §16, ajoute en Phase 5 pour combler le gap
    /// signale par l'agent 5.1 -- `sidebarBadgeIconSize`, 11 pt, etait reutilise en
    /// attendant).
    ///
    /// Valeur de FORME dessinee (un `Circle()`), PAS une taille de police de glyphe SF
    /// Symbol : a mettre a l'echelle Dynamic Type via `@ScaledMetric` directement sur le
    /// `frame` de la forme (voir `BulletedListItemContentView`), jamais via
    /// `View.slateIconFont(_:)` (reserve aux glyphes `Image(systemName:)`, dont la boite
    /// de dessin interne ne correspond pas au diametre visuel demande par la spec).
    static let listBulletSize: CGFloat = 6
}

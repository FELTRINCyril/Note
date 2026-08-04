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

    // MARK: - Depot de drag & drop

    /// Epaisseur de la ligne d'insertion affichee pendant un glisser-depose de bloc.
    static let editorDropIndicatorHeight: CGFloat = 2
}

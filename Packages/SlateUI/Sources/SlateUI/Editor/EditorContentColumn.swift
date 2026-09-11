import SwiftUI

/// Colonne de texte centree de l'editeur, largeur max `SlateGeometry.
/// editorMaxContentWidth` (720 pt), avec la gouttiere de chrome (`editorGutter`, 48 pt)
/// incluse dans la largeur totale reservee quand `includesGutter` est vrai. Utilisee
/// pour l'en-tete de note ET pour chaque bloc : c'est ce qui garantit que titre,
/// sous-titre et corps partagent exactement la meme marge de gauche (spec E4,
/// "Principe").
///
/// Voir la documentation de `EditorGeometry.swift` (section "Choix de mise en page
/// retenu pour la gouttiere") pour l'arbitrage : la gouttiere est INCLUSE dans le flux
/// (elargit la boite centree a `720 + 48`) plutot que flottante en overlay, pour rester
/// robuste dans un panneau d'editeur redimensionnable. Consequence acceptee : la
/// colonne de texte, bien que strictement 720 pt de large, est optiquement decalee
/// d'environ `editorGutter / 2` (24 pt) vers la droite par rapport au centre exact de
/// la fenetre.
///
/// ## Sortie de colonne d'un bloc individuel (Phase 10)
/// `EditorContentColumn` enveloppe TOUTE la liste de blocs d'un coup (voir son usage
/// dans `NoteDocumentView`), pas chaque bloc : la mise en page ci-dessus (deux
/// `Spacer` flexibles + une boite centree capee a `columnWidth`) reste **strictement
/// inchangee** pour ce cas -- c'est le chemin de code emprunte par tous les blocs
/// ordinaires, zero risque de regression.
///
/// Pour laisser un bloc PRECIS deborder (image "debord"/"pleine largeur", rangee de
/// colonnes), cette vue mesure sa propre largeur reelle (via un `GeometryReader` en
/// **arriere-plan**, meme idiome que `BlockFramePreferenceKey` deja utilise par
/// `SlateEditor` pour mesurer le cadre de chaque bloc -- un arriere-plan hérite de la
/// taille de la vue qu'il decore, il ne lui impose jamais une proposition infinie,
/// contrairement a un `GeometryReader` utilise directement comme corps de vue) et la
/// publie via `EnvironmentValues.slateEditorAvailableWidth`. Un bloc qui a besoin de
/// deborder lit cette valeur via le modificateur `View.slateBreakOutOfEditorColumn(
/// targetWidth:)` (voir `EditorColumnBreakout.swift`) : il ne touche jamais a cette vue
/// ni a `BlockContainer`.
///
/// Le point d'alignement de la gouttiere est preserve PAR CONSTRUCTION : tous les
/// blocs restent des freres au sein du MEME `VStack(alignment: .leading)` capé a
/// `columnWidth` ci-dessous. Un bloc qui declare une largeur de CONTENU explicitement
/// plus grande (via `.frame(width:)`) ne change pas la taille RAPPORTEE de ce `VStack`
/// a son parent (elle reste cappee a `columnWidth`, donc les deux `Spacer` de la ligne
/// ci-dessus restent identiques pour toutes les lignes) : seul le DESSIN de ce bloc
/// deborde visuellement vers la droite, sans jamais deplacer son bord gauche (ni donc
/// `BlockHandle`, positionne AVANT le contenu dans `BlockContainer`). Consequence
/// acceptee : si le panneau editeur est trop etroit pour la largeur demandee, le
/// debord est simplement rogne par les bords du `ScrollView` -- degradation
/// gracieuse, pas une rupture de mise en page pour les AUTRES blocs.
public struct EditorContentColumn<Content: View>: View {
    private let includesGutter: Bool
    private let content: Content

    /// Largeur reellement mesuree de cette colonne (donc du panneau editeur), publiee
    /// aux blocs enfants via `slateEditorAvailableWidth`. Initialisee a la largeur
    /// standard pour que le premier rendu (avant la premiere mesure de
    /// `GeometryReader`) reste coherent avec le comportement d'avant Phase 10.
    @State private var measuredWidth: CGFloat = SlateGeometry.editorMaxContentWidth + SlateGeometry.editorGutter

    public init(includesGutter: Bool = true, @ViewBuilder content: () -> Content) {
        self.includesGutter = includesGutter
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: Spacing.xl)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: columnWidth, alignment: .leading)
            Spacer(minLength: Spacing.xl)
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: EditorAvailableWidthPreferenceKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(EditorAvailableWidthPreferenceKey.self) { measuredWidth = $0 }
        .environment(\.slateEditorAvailableWidth, measuredWidth)
    }

    private var columnWidth: CGFloat {
        SlateGeometry.editorMaxContentWidth + (includesGutter ? SlateGeometry.editorGutter : 0)
    }
}

#Preview("EditorContentColumn - clair") {
    EditorContentColumn {
        Text("Colonne centree, 720 pt + gouttiere de 48 pt.")
            .slateFont(SlateFont.body)
            .foregroundStyle(SlateColor.textPrimary)
    }
    .frame(width: 900, height: 200)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("EditorContentColumn - sombre") {
    EditorContentColumn {
        Text("Colonne centree, 720 pt + gouttiere de 48 pt.")
            .slateFont(SlateFont.body)
            .foregroundStyle(SlateColor.textPrimary)
    }
    .frame(width: 900, height: 200)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}

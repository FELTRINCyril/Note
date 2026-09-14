import SwiftUI

/// Conteneur d'edition d'un bloc : gouttiere de chrome, aplat de selection, contour de
/// focus clavier, placeholder de bloc vide et ligne d'insertion de drag & drop. Neutre
/// quant au CONTENU du bloc (paragraphe, titre, code...) : tout passe par `content`
/// (spec E4, "Etats d'un bloc - BlockContainer + BlockHandle").
///
/// `SlateUI` ne connait ni `Block` ni `Note` (CLAUDE.md §4) : cette vue ne recoit qu'un
/// `SlateBlockState`, une position de plage, un identifiant opaque et des callbacks --
/// jamais un type metier. C'est `SlateEditor`/`SlateFeatures` qui la pilotent.
public struct BlockContainer<Content: View>: View {
    private let state: SlateBlockState
    private let rangePosition: SlateBlockRangePosition
    private let isEmpty: Bool
    private let placeholder: String
    /// Bord sur lequel afficher la ligne d'insertion de drag & drop, ou `nil` si ce
    /// bloc n'est pas la cible courante d'un glisser-depose. `.top`/`.bottom`
    /// (comportement d'origine, Phase 5) inserent une ligne HORIZONTALE a la frontiere
    /// avec le bloc voisin. `.leading`/`.trailing` (Phase 10, artboard I "Depot lateral
    /// -> colonne") tracent une ligne VERTICALE PLEINE HAUTEUR : le depot sur le bord
    /// lateral d'un bloc cree une colonne avec lui, au lieu d'inserer une ligne.
    private let dropEdge: Edge?
    /// Hauteur de la premiere ligne du CONTENU reel, pour centrer la poignee dessus.
    /// Dynamic Type (spec E4, "Accessibilite") : l'appelant DOIT passer la hauteur de
    /// ligne effective de sa typo mise a l'echelle, pas une constante figee -- la
    /// valeur par defaut (22,5 = 15 x `editorParagraphLineHeight`) ne convient qu'a un
    /// corps de texte a l'echelle standard.
    private let firstLineHeight: CGFloat
    private let blockID: String
    private let onInsert: () -> Void
    private let onMenu: () -> Void
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    public init(
        state: SlateBlockState = .normal,
        rangePosition: SlateBlockRangePosition = .single,
        isEmpty: Bool = false,
        // `nil` plutot qu'un litteral en defaut : `SlateUIStrings` (le catalogue de
        // localisation de ce module) est INTERNE, une expression par defaut d'une API
        // PUBLIQUE doit etre au moins aussi visible que l'API elle-meme -- resolu dans
        // le corps de l'initialiseur plutot que de rendre tout le catalogue public.
        placeholder: String? = nil,
        dropEdge: Edge? = nil,
        firstLineHeight: CGFloat = 15 * SlateGeometry.editorParagraphLineHeight,
        blockID: String = "",
        onInsert: @escaping () -> Void = {},
        onMenu: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.state = state
        self.rangePosition = rangePosition
        self.isEmpty = isEmpty
        self.placeholder = placeholder ?? SlateUIStrings.blockParagraphPlaceholder
        self.dropEdge = dropEdge
        self.firstLineHeight = firstLineHeight
        self.blockID = blockID
        self.onInsert = onInsert
        self.onMenu = onMenu
        self.content = content()
    }

    /// Le chrome apparait au survol OU quand l'etat du bloc l'exige (focus, selection,
    /// focus clavier -- voir `SlateBlockState.showsChrome`).
    private var chromeVisible: Bool { isHovering || state.showsChrome }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            BlockHandle(isVisible: chromeVisible, dragPayload: blockID, onInsert: onInsert, onMenu: onMenu)
                .frame(height: firstLineHeight, alignment: .center)

            ZStack(alignment: .topLeading) {
                if isEmpty, state == .focused {
                    Text(placeholder)
                        .slateFont(SlateFont.body)
                        .foregroundStyle(SlateColor.textPlaceholder)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.vertical, SlateGeometry.editorBlockSpacing / 2)
            .background(selectionFill)
            .overlay(focusRing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SlateGeometry.editorBlockSpacing / 2)
        .overlay(alignment: dropOverlayAlignment) { dropIndicator }
        .contentShape(Rectangle())
        .onHover { hovering in
            let animation = SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion)
            withAnimation(animation) {
                isHovering = hovering
            }
        }
        // La selection (contenu) et le focus clavier (navigation) sont annonces
        // separement, comme ils sont peints separement (spec E4, "Focus != selection").
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(state == .selected ? .isSelected : [])
    }

    // MARK: - Aplat de selection (`SlateColor.blockSelectedBackground`)
    //
    // Les coins ne s'arrondissent qu'aux extremites de la plage ; l'aplat se prolonge
    // vers le bas de `editorBlockSpacing` pour combler le vide entre deux blocs de la
    // meme plage (spec E4 : "aplat continu ... les 4 pt intermediaires combles").
    // Le debord horizontal (spec E4 : "8 pt de chaque cote du texte") est obtenu par un
    // padding NEGATIF sur la FORME (pas sur le texte) : le texte garde sa largeur
    // complete, seul l'aplat s'etend visuellement au-dela sans modifier la taille
    // rapportee au parent (donc sans jamais reduire la colonne de 720 pt).
    @ViewBuilder private var selectionFill: some View {
        if state.showsSelectionFill {
            UnevenRoundedRectangle(
                topLeadingRadius: rangePosition.topRadius,
                bottomLeadingRadius: rangePosition.bottomRadius,
                bottomTrailingRadius: rangePosition.bottomRadius,
                topTrailingRadius: rangePosition.topRadius
            )
            .fill(SlateColor.blockSelectedBackground)
            .padding(.horizontal, -SlateGeometry.editorSelectionBleed)
            .padding(.bottom, rangePosition.extendsDown ? -SlateGeometry.editorBlockSpacing : 0)
        }
    }

    // MARK: - Focus clavier -- jamais un aplat, toujours un contour
    //
    // Arbitrage Cyril (Phase 5) : le contour translucide `focusRing` mesure, une fois
    // compose sur `bg.editor`, SOUS le minimum 3:1 pour un element non textuel (voir
    // `EditorAccessibilityTests` -- la spec E4 annoncait a tort "3,08:1 / 3,21:1, juste
    // au-dessus du minimum"). Le lisere 1 pt opaque en `accent.default`, dessine ICI en
    // renfort, n'est donc pas une simple securite : c'est lui qui fait reellement
    // atteindre l'AA non textuel (~4,02:1 / ~4,66:1). Ne PAS toucher au token
    // `focusRing` lui-meme (partage avec la sidebar et la liste de notes).
    @ViewBuilder private var focusRing: some View {
        if state.showsFocusRing {
            ZStack {
                RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                    .strokeBorder(SlateColor.focusRing, lineWidth: SlateGeometry.focusRingWidth)
                    .padding(-SlateGeometry.focusRingOffset)
                RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                    .strokeBorder(SlateColor.accentDefault, lineWidth: SlateGeometry.strokeHairline)
            }
        }
    }

    /// Comportement d'origine (Phase 5) preserve a l'identique pour `.top`/`.bottom`/
    /// `nil` : seuls `.leading`/`.trailing` (Phase 10) sont un ajout.
    private var dropOverlayAlignment: Alignment {
        switch dropEdge {
        case .top: .top
        case .leading: .leading
        case .trailing: .trailing
        case .bottom, nil: .bottom
        }
    }

    // MARK: - Ligne d'insertion (`SlateColor.blockDropIndicator`)
    @ViewBuilder private var dropIndicator: some View {
        switch dropEdge {
        case .top, .bottom:
            Capsule(style: .continuous)
                .fill(SlateColor.blockDropIndicator)
                .frame(height: SlateGeometry.editorDropIndicatorHeight)
                .padding(.leading, SlateGeometry.editorGutter)
                .transition(.opacity)
        case .leading, .trailing:
            // Depot lateral : ce bloc va devenir une COLONNE avec le bloc depose
            // (artboard I, "Sombre - depot lateral -> colonne"). Ligne PLEINE HAUTEUR,
            // contrairement a la ligne horizontale ci-dessus qui ne marque qu'une
            // frontiere ENTRE deux blocs -- ici c'est le bloc survole lui-meme qui
            // devient la frontiere.
            Capsule(style: .continuous)
                .fill(SlateColor.blockDropIndicator)
                .frame(width: SlateGeometry.editorDropIndicatorHeight)
                .frame(maxHeight: .infinity)
                .transition(.opacity)
        case nil:
            EmptyView()
        }
    }
}

// MARK: - Galerie d'etats (spec E4, "GALERIE D'ETATS")

private struct BlockContainerGalleryPreview: View {
    var body: some View {
        EditorContentColumn {
            VStack(alignment: .leading, spacing: 0) {
                block("Normal - aucun chrome, aucun aplat.", state: .normal)
                block("Survol - le chrome apparait, le texte ne bouge pas.", state: .hovered)
                block("Focus (edition) - caret dans le bloc.", state: .focused)
                block("", state: .focused, isEmpty: true)
                block("Selectionne - aplat block.selected.bg, radius 8.", state: .selected)
                block("Focus clavier - contour 3 pt + lisere 1 pt, aucun aplat.", state: .keyboardFocused)
            }
        }
        .padding(.vertical, Spacing.lg)
        .background(SlateColor.bgEditor)
    }

    private func block(_ text: String, state: SlateBlockState, isEmpty: Bool = false) -> some View {
        BlockContainer(state: state, isEmpty: isEmpty, blockID: text) {
            Text(text)
                .slateFont(SlateFont.body)
                .foregroundStyle(SlateColor.textPrimary)
        }
    }
}

#Preview("BlockContainer - galerie, clair") {
    BlockContainerGalleryPreview()
        .frame(width: 900, height: 640)
        .environment(\.colorScheme, .light)
}

#Preview("BlockContainer - galerie, sombre") {
    BlockContainerGalleryPreview()
        .frame(width: 900, height: 640)
        .environment(\.colorScheme, .dark)
}

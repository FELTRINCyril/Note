//  BlockContainer.swift — SlateUI
//  Conteneur d'édition d'un bloc : gouttière de chrome, aplats d'état, focus ring,
//  placeholder, caret et ligne d'insertion. Neutre quant au *contenu* du bloc :
//  paragraphe, titre, code (E7)… tout passe par `content`.

import SwiftUI

public struct BlockContainer<Content: View>: View {

    // État
    var state: SlateBlockState = .normal
    /// Position dans une sélection multi-blocs (coins de l'aplat).
    var rangePosition: SlateBlockRangePosition = .single
    /// Bloc vide → placeholder « Tapez / pour les commandes » quand il est en édition.
    var isEmpty: Bool = false
    var placeholder: String = "Tapez / pour les commandes"
    /// Ligne d'insertion de drag & drop, au-dessus ou en dessous.
    var dropEdge: Edge? = nil

    // Alignement du chrome sur la première ligne du bloc (titres, listes, code…)
    /// Hauteur de la première ligne du contenu, pour centrer la poignée dessus.
    var firstLineHeight: CGFloat = 22

    var blockID: String = ""
    var onInsert: () -> Void = {}
    var onMenu: () -> Void = {}
    @ViewBuilder var content: () -> Content

    @Environment(\.slateAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    public init(state: SlateBlockState = .normal,
                rangePosition: SlateBlockRangePosition = .single,
                isEmpty: Bool = false,
                placeholder: String = "Tapez / pour les commandes",
                dropEdge: Edge? = nil,
                firstLineHeight: CGFloat = 22,
                blockID: String = "",
                onInsert: @escaping () -> Void = {},
                onMenu: @escaping () -> Void = {},
                @ViewBuilder content: @escaping () -> Content) {
        self.state = state; self.rangePosition = rangePosition
        self.isEmpty = isEmpty; self.placeholder = placeholder
        self.dropEdge = dropEdge; self.firstLineHeight = firstLineHeight
        self.blockID = blockID; self.onInsert = onInsert; self.onMenu = onMenu
        self.content = content
    }

    /// Le chrome apparaît au survol *ou* quand l'état du bloc l'exige.
    private var chromeVisible: Bool { isHovering || state.showsChrome }

    public var body: some View {
        HStack(alignment: .top, spacing: SlateSpace.s) {
            // Gouttière : hors du flux du texte, largeur fixe → la colonne ne bouge jamais.
            BlockHandle(isVisible: chromeVisible, dragPayload: blockID,
                        onInsert: onInsert, onMenu: onMenu)
                .frame(height: firstLineHeight, alignment: .center)

            ZStack(alignment: .topLeading) {
                if isEmpty, state == .focused {
                    Text(placeholder)
                        .slateFont(.body)
                        .foregroundStyle(SlateColors.textPlaceholder)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, SlateEditorMetrics.selectionBleed)
            .padding(.vertical, SlateEditorMetrics.blockSpacing / 2)
            .background(selectionFill)
            .overlay(focusRing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SlateEditorMetrics.blockSpacing / 2)
        .overlay(alignment: dropEdge == .top ? .top : .bottom) { dropIndicator }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(SlateMotion.standard(SlateMotion.fast, reduceMotion: reduceMotion)) {
                isHovering = hovering
            }
        }
        // Accessibilité : la sélection (contenu) et le focus clavier (navigation) sont
        // annoncés séparément, comme ils sont peints séparément.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(state == .selected ? .isSelected : [])
    }

    // MARK: Aplat de sélection (`block.selected.bg`)
    // Les coins s'arrondissent seulement aux extrémités de la plage ; l'aplat se prolonge
    // vers le bas de `blockSpacing` pour combler le vide entre deux blocs de la même plage.
    @ViewBuilder private var selectionFill: some View {
        if state.showsSelectionFill {
            UnevenRoundedRectangle(
                topLeadingRadius: rangePosition.topRadius,
                bottomLeadingRadius: rangePosition.bottomRadius,
                bottomTrailingRadius: rangePosition.bottomRadius,
                topTrailingRadius: rangePosition.topRadius
            )
            .fill(SlateEditorColors.blockSelected)
            .padding(.bottom, rangePosition.extendsDown ? -SlateEditorMetrics.blockSpacing : 0)
        }
    }

    // MARK: Focus clavier — jamais un aplat, toujours un contour
    @ViewBuilder private var focusRing: some View {
        if state.showsFocusRing {
            RoundedRectangle(cornerRadius: SlateRadius.m)
                .strokeBorder(accent.focusRing, lineWidth: SlateStroke.focusRingWidth)
                .padding(-SlateStroke.focusRingOffset)
        }
    }

    // MARK: Ligne d'insertion (`block.dropIndicator`)
    @ViewBuilder private var dropIndicator: some View {
        if dropEdge != nil {
            Capsule(style: .continuous)
                .fill(accent.blockDropIndicator)
                .frame(height: SlateEditorMetrics.dropIndicatorHeight)
                .padding(.leading, SlateEditorMetrics.gutter)
                .transition(.opacity)
        }
    }
}

// MARK: - Caret

/// Curseur de saisie : 2 pt, couleur d'accent (`insertionPoint` macOS), clignotement 1,06 s.
/// Il vit **dans** le bloc focalisé et prend la hauteur de ligne de sa typo : passer d'un bloc
/// à l'autre au clavier ne dessine aucune ligne entre les blocs — seul le drag le fait.
public struct BlockCaret: View {
    var lineHeight: CGFloat = 22
    var isBlinking: Bool = true

    @Environment(\.slateAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = true

    public init(lineHeight: CGFloat = 22, isBlinking: Bool = true) {
        self.lineHeight = lineHeight; self.isBlinking = isBlinking
    }

    public var body: some View {
        Rectangle()
            .fill(accent.caret)
            .frame(width: SlateEditorMetrics.caretWidth, height: lineHeight)
            .opacity(visible ? 1 : 0)
            .onAppear {
                guard isBlinking, !reduceMotion else { visible = true; return }
                withAnimation(.linear(duration: 0.53).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Colonne d'édition (conteneur global)

/// Colonne de texte centrée, largeur max `editor.maxContentWidth` (720 pt),
/// avec la gouttière de chrome réservée à gauche. Utilisée par l'en-tête *et* par les blocs,
/// pour que titre, sous-titre et corps partagent exactement la même marge de gauche.
public struct EditorContentColumn<Content: View>: View {
    var includesGutter: Bool = true
    @ViewBuilder var content: () -> Content

    public init(includesGutter: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.includesGutter = includesGutter; self.content = content
    }

    public var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: SlateSpace.xl)
            VStack(alignment: .leading, spacing: 0) { content() }
                .frame(maxWidth: SlateEditorMetrics.maxContentWidth
                       + (includesGutter ? SlateEditorMetrics.gutter : 0),
                       alignment: .leading)
            Spacer(minLength: SlateSpace.xl)
        }
    }
}

import AppKit
import SwiftUI

/// Rangee de colonnes (design/tokens.md §16, artboard J de
/// `Slate P1 - Formatage & blocs.dc.html`). Neutre quant au CONTENU de chaque colonne
/// (`SlateUI` ne connait pas `Block`, meme contrat que `BlockContainer`) : `content(i)`
/// rend le contenu de la colonne `i`, a l'appelant (`SlateEditor`) de brancher une
/// pile de blocs par colonne.
///
/// A utiliser via `View.slateBreakOutOfEditorColumn(targetWidth: nil)` (Phase 10) sur
/// le RESULTAT de cette vue si la rangee doit occuper toute la largeur du panneau
/// editeur plutot que la seule largeur de la colonne de texte -- cette vue elle-meme
/// ne fait aucune hypothese sur sa largeur totale, elle se contente de mesurer ce
/// qu'on lui propose (voir `measuredWidth`).
///
/// Largeurs memorisees en FRACTIONS (`fractions`, `Binding<[CGFloat]>`), pas en points
/// (artboard J : "survivre au redimensionnement de la fenetre") -- toute la logique de
/// conversion fraction/points est dans `ColumnFractions`, pure et testee separement.
public struct ColumnsBlockView<Content: View>: View {
    @Binding private var fractions: [CGFloat]
    private let content: (Int) -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Largeur reellement mesuree de cette rangee (voir `EditorContentColumn` pour le
    /// meme idiome : `GeometryReader` en arriere-plan, jamais en corps de vue direct,
    /// pour ne pas forcer une hauteur infinie dans le `LazyVStack` de l'editeur).
    @State private var measuredWidth: CGFloat = SlateGeometry.editorMaxContentWidth

    public init(fractions: Binding<[CGFloat]>, @ViewBuilder content: @escaping (Int) -> Content) {
        self._fractions = fractions
        self.content = content
    }

    private var isStacked: Bool {
        ColumnFractions.shouldStack(availableWidth: measuredWidth, dynamicTypeSize: dynamicTypeSize)
    }

    public var body: some View {
        Group {
            if isStacked {
                stackedBody
            } else {
                sideBySideBody
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ColumnsBlockWidthPreferenceKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(ColumnsBlockWidthPreferenceKey.self) { measuredWidth = $0 }
    }

    // MARK: - Empilement (< 560 pt ou `.accessibility1`+, artboard J "sombre")

    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: SlateGeometry.columnGap) {
            ForEach(fractions.indices, id: \.self) { index in
                content(index)
                if index < fractions.count - 1 {
                    Rectangle()
                        .fill(SlateColor.dividerColor)
                        .frame(height: SlateGeometry.strokeHairline)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: - Cote a cote (artboard J "clair")

    private var sideBySideBody: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(fractions.indices, id: \.self) { index in
                content(index)
                    .frame(width: ColumnFractions.width(for: fractions, at: index, totalWidth: measuredWidth))
                if index < fractions.count - 1 {
                    ColumnResizer(index: index, fractions: $fractions, totalWidth: measuredWidth)
                }
            }
        }
    }
}

/// Separateur/poignee de redimensionnement entre deux colonnes adjacentes. Occupe
/// TOUTE la largeur de `columnGap` (24 pt) -- pas de `spacing` supplementaire sur le
/// `HStack` parent -- pour que l'espace inter-colonnes annonce par le design soit
/// exactement celui-la, sans en ajouter un second implicite.
///
/// Invisible au repos (artboard J : "invisible au repos"), trait `strokeHairline` en
/// `separator` (`column.resizer` = `separator`, deja alias dans `EditorColors.swift`)
/// des que la souris survole la RANGEE de colonnes (meme s'il n'est pas actif) pour
/// signaler discretement la frontiere, puis 4 pt en `accent.default` au survol/saisie
/// du separateur lui-meme.
private struct ColumnResizer: View {
    let index: Int
    @Binding var fractions: [CGFloat]
    let totalWidth: CGFloat

    @State private var isHovering = false
    @State private var isDragging = false
    /// Fractions au DEBUT du geste de glissement en cours -- `DragGesture.translation`
    /// est cumulatif depuis le debut du geste, jamais un delta entre deux appels (meme
    /// piege que documente sur `ImageBlockContentView.resizeChanged`).
    @State private var dragStartFractions: [CGFloat]?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isActive: Bool { isHovering || isDragging }

    var body: some View {
        RoundedRectangle(cornerRadius: SlateGeometry.columnResizerWidth / 2)
            .fill(isActive ? SlateColor.accentDefault : SlateColor.separator.opacity(isHovering ? 1 : 0))
            .frame(width: isActive ? SlateGeometry.columnResizerWidth : SlateGeometry.strokeHairline)
            .frame(width: SlateGeometry.columnGap)
            .contentShape(Rectangle())
            .onHover { hovering in
                let animation = SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion)
                withAnimation(animation) { isHovering = hovering }
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .local)
                    .onChanged { value in
                        isDragging = true
                        let start = dragStartFractions ?? fractions
                        dragStartFractions = start
                        fractions = ColumnFractions.resizing(
                            start, at: index, byDelta: value.translation.width, totalWidth: totalWidth
                        )
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragStartFractions = nil
                    }
            )
            .accessibilityLabel("Largeur des colonnes \(index + 1) et \(index + 2)")
            // Equivalent clavier obligatoire (artboard J) : la souris n'est pas le seul
            // moyen d'ajuster la largeur des colonnes. Pas d'annonce de valeur precise
            // (aucun contexte VoiceOver standard pour "fraction de colonne") : le
            // deplacement lui-meme est l'information utile.
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = Spacing.lg
                let delta: CGFloat = direction == .increment ? step : -step
                fractions = ColumnFractions.resizing(fractions, at: index, byDelta: delta, totalWidth: totalWidth)
            }
    }
}

private struct ColumnsBlockWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { SlateGeometry.editorMaxContentWidth }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Previews

private struct ColumnsBlockGalleryPreview: View {
    @State private var fractions: [CGFloat] = [0.5, 0.25, 0.25]

    var body: some View {
        EditorContentColumn {
            ColumnsBlockView(fractions: $fractions) { index in
                Text(columnText(index))
                    .slateFont(SlateFont.body)
                    .foregroundStyle(SlateColor.textPrimary)
            }
        }
        .padding(.vertical, Spacing.lg)
        .background(SlateColor.bgEditor)
    }

    private func columnText(_ index: Int) -> String {
        switch index {
        case 0: "Colonne large. Chaque colonne est un conteneur de blocs a part entiere."
        case 1: "Colonne moyenne."
        default: "Colonne etroite."
        }
    }
}

#Preview("ColumnsBlockView - 3 colonnes cote a cote, clair") {
    ColumnsBlockGalleryPreview()
        .frame(width: 800, height: 220)
        .environment(\.colorScheme, .light)
}

#Preview("ColumnsBlockView - 3 colonnes cote a cote, sombre") {
    ColumnsBlockGalleryPreview()
        .frame(width: 800, height: 220)
        .environment(\.colorScheme, .dark)
}

#Preview("ColumnsBlockView - empilement (< 560 pt), sombre") {
    ColumnsBlockGalleryPreview()
        .frame(width: 460, height: 320)
        .environment(\.colorScheme, .dark)
}

#Preview("ColumnsBlockView - empilement (.accessibility1), clair") {
    ColumnsBlockGalleryPreview()
        .frame(width: 800, height: 420)
        .environment(\.dynamicTypeSize, .accessibility1)
        .environment(\.colorScheme, .light)
}

import SwiftUI

/// Cadre d'un bloc image affiche/selectionne, artboard A de
/// `Slate P2 - Medias & pieces jointes.dc.html` (Phase 9) : dimensions, badge de palier,
/// legende editable, barre d'alignement, poignees de redimensionnement.
///
/// Vue pure et generique sur son CONTENU (`Content`, l'image reelle -- `SlateEditor` y
/// injecte un `Image`/`AsyncImage` charge depuis le modele) : `SlateUI` ne sait pas
/// decoder un fichier image, seulement mettre en scene ce qu'on lui donne.
public struct ImageFrameView<Content: View>: View {
    /// Les trois points de saisie du redimensionnement (artboard A : gauche, droite,
    /// bas-centre).
    public enum ResizeHandle: CaseIterable, Sendable {
        case leading
        case trailing
        case bottom
    }

    private let content: Content
    private let dimensionsText: String
    private let alignment: SlateImageAlignment
    private let isSelected: Bool
    /// Paliers proposes par la barre d'alignement, voir `MediaAlignmentBar.init`.
    private let alignmentOptions: [SlateImageAlignment]
    @Binding private var caption: String
    private let captionPlaceholder: String
    private let onSelectAlignment: (SlateImageAlignment) -> Void
    private let onMenu: () -> Void
    private let onResize: (ResizeHandle, CGSize) -> Void
    private let onResizeEnded: (ResizeHandle) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        dimensionsText: String,
        alignment: SlateImageAlignment,
        isSelected: Bool,
        caption: Binding<String>,
        alignmentOptions: [SlateImageAlignment] = SlateImageAlignment.allCases,
        captionPlaceholder: String = "Ajouter une legende",
        onSelectAlignment: @escaping (SlateImageAlignment) -> Void = { _ in },
        onMenu: @escaping () -> Void = {},
        onResize: @escaping (ResizeHandle, CGSize) -> Void = { _, _ in },
        onResizeEnded: @escaping (ResizeHandle) -> Void = { _ in },
        @ViewBuilder content: () -> Content
    ) {
        self.dimensionsText = dimensionsText
        self.alignment = alignment
        self.isSelected = isSelected
        self._caption = caption
        self.alignmentOptions = alignmentOptions
        self.captionPlaceholder = captionPlaceholder
        self.onSelectAlignment = onSelectAlignment
        self.onMenu = onMenu
        self.onResize = onResize
        self.onResizeEnded = onResizeEnded
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            imageArea
            captionRow
            if isSelected {
                MediaAlignmentBar(selection: alignment, options: alignmentOptions, onSelect: onSelectAlignment)
            }
        }
    }

    private var imageArea: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium))
            .overlay(alignment: .topLeading) { dimensionsLabel }
            .overlay(alignment: .topTrailing) { topControls }
            .overlay(alignment: .bottomTrailing) { widthBadge }
            .overlay(selectionOutline)
            .overlay(alignment: .leading) { handle(.leading) }
            .overlay(alignment: .trailing) { handle(.trailing) }
            .overlay(alignment: .bottom) { handle(.bottom) }
    }

    @ViewBuilder
    private var selectionOutline: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                .inset(by: -SlateGeometry.mediaSelectionOutlineOffset)
                .stroke(SlateColor.accentDefault, lineWidth: SlateGeometry.mediaSelectionOutlineWidth)
        }
    }

    @ViewBuilder
    private var dimensionsLabel: some View {
        if isSelected {
            Text(dimensionsText)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.foregroundOnAccentFill)
                .padding(.horizontal, Spacing.xs)
                .padding(.top, Spacing.xs)
        }
    }

    @ViewBuilder
    private var topControls: some View {
        if isSelected {
            Button(action: onMenu) {
                Image(systemName: "ellipsis")
                    .slateIconFont(SlateGeometry.mediaPillGlyphSize, weight: .bold)
                    .foregroundStyle(SlateColor.foregroundOnAccentFill)
                    .frame(width: SlateGeometry.mediaPillControlHeight, height: SlateGeometry.mediaPillControlHeight)
                    .background(
                        RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                            .fill(SlateColor.mediaOverlayChipBackground)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Options de l'image")
            .padding(Spacing.xs)
        }
    }

    @ViewBuilder
    private var widthBadge: some View {
        if isSelected {
            Text(alignment.widthBadgeText)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.foregroundOnAccentFill)
                .padding(.horizontal, Spacing.xs)
                .frame(height: SlateGeometry.mediaPillControlHeight - Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                        .fill(SlateColor.accentDefault)
                )
                .padding(Spacing.sm)
        }
    }

    @ViewBuilder
    private func handle(_ position: ResizeHandle) -> some View {
        if isSelected {
            let isVertical = position != .bottom
            let hitSize = dynamicTypeSize.isAccessibilitySize
                ? SlateGeometry.mediaHandleHitSizeAccessibility
                : SlateGeometry.mediaHandleHitSize
            let visualWidth = isVertical ? SlateGeometry.mediaHandleWidth : SlateGeometry.mediaHandleHeight
            let visualHeight = isVertical ? SlateGeometry.mediaHandleHeight : SlateGeometry.mediaHandleWidth
            let margin = (hitSize - min(visualWidth, visualHeight)) / 2

            RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall / 2)
                .fill(SlateColor.mediaHandleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall / 2)
                        .strokeBorder(SlateColor.mediaHandleBorder, lineWidth: SlateGeometry.mediaHandleBorderWidth)
                )
                .frame(width: visualWidth, height: visualHeight)
                .padding(margin)
                .padding(-margin)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { onResize(position, $0.translation) }
                        .onEnded { _ in onResizeEnded(position) }
                )
                .accessibilityLabel("Redimensionner l'image")
                .accessibilityAddTraits(.isButton)
        }
    }

    @ViewBuilder
    private var captionRow: some View {
        if isSelected {
            TextField(captionPlaceholder, text: $caption)
                .textFieldStyle(.plain)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textSecondary)
        } else if !caption.isEmpty {
            Text(caption)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textSecondary)
        }
    }
}

#Preview("ImageFrameView - selectionnee, clair") {
    ImageFrameViewPreview(isSelected: true)
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("ImageFrameView - affichee, sombre") {
    ImageFrameViewPreview(isSelected: false)
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

private struct ImageFrameViewPreview: View {
    let isSelected: Bool
    @State private var alignment: SlateImageAlignment = .center
    @State private var caption = "Architecture des blocs, revision de septembre."

    var body: some View {
        ImageFrameView(
            dimensionsText: "schema-blocs.png \u{b7} 1 640 \u{d7} 984",
            alignment: alignment,
            isSelected: isSelected,
            caption: $caption,
            onSelectAlignment: { alignment = $0 },
            content: {
                RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                    .fill(SlateColor.surfaceTertiary)
                    .frame(height: 220)
            }
        )
    }
}

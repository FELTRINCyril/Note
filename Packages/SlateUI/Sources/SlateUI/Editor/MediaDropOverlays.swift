import SwiftUI

/// Ligne d'insertion affichee pendant un glisser-depose de fichiers ENTRE deux blocs,
/// artboard C de `Slate P2 - Medias & pieces jointes.dc.html` (Phase 9) : "Meme ligne
/// d'insertion que pour le deplacement de blocs -- un seul vocabulaire de depot dans
/// toute l'app." Reutilise `block.dropIndicator`/`editorDropIndicatorHeight`, deja
/// definis pour le reordonnancement de blocs (Phase 5) : aucune nouvelle geometrie de
/// ligne ici.
///
/// "Le badge de comptage n'apparait qu'a partir de deux fichiers" (artboard C) : avec un
/// seul fichier, seule la ligne (sans libelle) est affichee -- exactement le meme visuel
/// qu'un depot de bloc ordinaire.
public struct BlockDropIndicatorView: View {
    private let fileCount: Int
    private let itemLabel: String

    // `nil` plutot qu'un litteral en defaut : meme motif que
    // `BlockContainer.init(placeholder:)`, voir sa documentation.
    public init(fileCount: Int, itemLabel: String? = nil) {
        self.fileCount = fileCount
        self.itemLabel = itemLabel ?? SlateUIStrings.mediaDropIndicatorItemLabelDefault
    }

    public var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(SlateColor.stateSelected)
                .frame(width: SlateGeometry.mediaDropIndicatorDotSize, height: SlateGeometry.mediaDropIndicatorDotSize)
                .offset(x: -SlateGeometry.mediaDropIndicatorDotSize / 2)

            Rectangle()
                .fill(SlateColor.stateSelected)
                .frame(height: SlateGeometry.editorDropIndicatorHeight)

            if fileCount >= 2 {
                Text(SlateUIStrings.mediaDropIndicatorInsertMultiple(count: fileCount, itemLabel: itemLabel))
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(SlateColor.foregroundOnAccentFill)
                    .padding(.horizontal, Spacing.xs)
                    .frame(height: SlateGeometry.mediaPillControlHeight - Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                            .fill(SlateColor.stateSelected)
                    )
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            fileCount >= 2
                ? SlateUIStrings.mediaDropIndicatorInsertMultiple(count: fileCount, itemLabel: itemLabel)
                : SlateUIStrings.mediaDropIndicatorInsertSingle
        )
    }
}

/// Voile de depot sur la note ENTIERE, quand le curseur n'est proche d'aucune frontiere
/// entre blocs, artboard C : "la note entiere devient la cible et le contenu s'atenue.
/// Les fichiers sont alors ajoutes a la fin de la note." et "Le voile de depot utilise
/// `accent.subtle` et non un scrim noir : la note reste identifiable derriere."
public struct NoteDropOverlayView: View {
    private let destinationTitle: String
    private let summary: String

    public init(destinationTitle: String, summary: String) {
        self.destinationTitle = destinationTitle
        self.summary = summary
    }

    public var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "arrow.up.doc")
                .slateIconFont(28, weight: .regular)
                .foregroundStyle(SlateColor.mediaDropzoneActiveLabel)
            Text(SlateUIStrings.mediaNoteDropTitle(destinationTitle: destinationTitle))
                .slateFont(SlateFont.subtitle)
                .foregroundStyle(SlateColor.mediaDropzoneActiveLabel)
            Text(summary)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.foregroundOnAccentFill)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                .fill(SlateColor.mediaDropzoneActiveBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                .strokeBorder(
                    SlateColor.mediaDropzoneActiveBorder,
                    style: StrokeStyle(lineWidth: SlateGeometry.mediaDropzoneActiveBorderWidth, dash: [5, 3])
                )
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("BlockDropIndicatorView - 3 fichiers, clair") {
    VStack(alignment: .leading, spacing: Spacing.xs) {
        Text("Le curseur survole la frontiere entre deux paragraphes.")
        BlockDropIndicatorView(fileCount: 3, itemLabel: "images")
        Text("Meme ligne d'insertion que pour le deplacement de blocs.")
    }
    .padding()
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("BlockDropIndicatorView - 1 fichier (pas de badge)") {
    BlockDropIndicatorView(fileCount: 1)
        .padding()
        .background(SlateColor.bgEditor)
}

#Preview("NoteDropOverlayView - sombre") {
    ZStack {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Architecture de l'editeur").slateFont(SlateFont.titleSecondary)
            Text("Quand le curseur n'est proche d'aucune frontiere...")
        }
        .padding()
        .opacity(0.35)

        NoteDropOverlayView(
            destinationTitle: "Architecture de l'editeur",
            summary: "3 images et 1 PDF -- ajoutes a la fin de la note"
        )
        .padding(Spacing.md)
    }
    .frame(width: 600, height: 280)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}

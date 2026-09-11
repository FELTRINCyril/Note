import SwiftUI

/// Barre d'alignement/palier d'un bloc image, artboard A de
/// `Slate P2 - Medias & pieces jointes.dc.html` (Phase 9) : "l'alignement actif porte une
/// coche, pas seulement l'aplat d'accent" -- l'information n'est jamais portee par la
/// seule couleur.
public struct MediaAlignmentBar: View {
    private let selection: SlateImageAlignment
    private let options: [SlateImageAlignment]
    private let onSelect: (SlateImageAlignment) -> Void

    /// `options` limite les paliers REELLEMENT proposes. Defaut : les cinq du design.
    ///
    /// Ce parametre existe pour la regle d'honnetete d'interface du projet : ne jamais
    /// proposer un controle qui n'a pas d'effet. Les paliers hors colonne (`.overflow`,
    /// `.fullWidth`) attendent que `EditorContentColumn` sache laisser un bloc sortir de
    /// la colonne de 720 pt, ce qui vient avec la mise en colonnes (phase 10) : d'ici la,
    /// l'appelant les retire de la liste plutot que de les afficher inertes.
    public init(
        selection: SlateImageAlignment,
        options: [SlateImageAlignment] = SlateImageAlignment.allCases,
        onSelect: @escaping (SlateImageAlignment) -> Void
    ) {
        self.selection = selection
        self.options = options
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(inColumnOptions) { alignment in
                pill(for: alignment)
            }
            if !outOfColumnOptions.isEmpty {
                Divider().frame(height: SlateGeometry.mediaPillControlHeight - Spacing.xs)
                ForEach(outOfColumnOptions) { alignment in
                    pill(for: alignment)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Paliers qui tiennent dans la colonne de texte, separes des autres par le filet
    /// vertical du design (artboard A).
    private var inColumnOptions: [SlateImageAlignment] {
        options.filter { [.left, .center, .right].contains($0) }
    }

    private var outOfColumnOptions: [SlateImageAlignment] {
        options.filter { [.overflow, .fullWidth].contains($0) }
    }

    private func pill(for alignment: SlateImageAlignment) -> some View {
        let isActive = alignment == selection
        return Button {
            onSelect(alignment)
        } label: {
            HStack(spacing: Spacing.xs) {
                if isActive {
                    Image(systemName: "checkmark")
                        .slateIconFont(SlateGeometry.mediaPillGlyphSize, weight: .bold)
                }
                Text(alignment.label)
                    .slateFont(SlateFont.caption)
            }
            .foregroundStyle(isActive ? SlateColor.foregroundOnAccentFill : SlateColor.textPrimary)
            .padding(.horizontal, Spacing.sm)
            .frame(height: SlateGeometry.mediaPillControlHeight)
            .background(
                RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                    .fill(isActive ? SlateColor.accentDefault : SlateColor.stateHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                    .strokeBorder(
                        isActive ? Color.clear : SlateColor.borderDefault,
                        lineWidth: SlateGeometry.strokeHairline
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .accessibilityLabel(alignment.label)
    }
}

#Preview("MediaAlignmentBar - clair") {
    MediaAlignmentBarPreview()
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("MediaAlignmentBar - sombre") {
    MediaAlignmentBarPreview()
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

private struct MediaAlignmentBarPreview: View {
    @State private var selection: SlateImageAlignment = .center

    var body: some View {
        MediaAlignmentBar(selection: selection) { selection = $0 }
    }
}

import SlateModel
import SlateUI
import SwiftUI

/// Palette de surlignage et de couleur de texte (docs/07_typographie_formatage.md,
/// artboard P1 B) : deux rangees de pastilles rondes de 22 pt, une COCHE sur la valeur
/// active (pas seulement un anneau -- l'etat ne doit pas etre porte par la seule
/// couleur, meme regle que `FormatBarButton`), et une action "Retirer tout le
/// formatage". Presentee en `.popover` par `FormatBarView` -- meme precedent deja en
/// production que `BlockMenuView` (Phase 5) : un clic explicite sur le bouton
/// "surlignage" de la barre est une action ponctuelle, pas une frappe continue a
/// preserver (voir la distinction documentee dans `SlashMenuOverlay`, qui elle NE PEUT
/// PAS se permettre un `.popover`).
struct FormatColorPopoverView: View {
    let block: Block
    let editorController: EditorController
    let range: RichTextRange

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            swatchRow(
                title: EditorStrings.formatBarHighlightSectionTitle,
                tokens: SlateHighlightToken.allCases.map { ($0.rawValue, $0.background) },
                currentIdentifier: editorController.activeHighlight(in: block, range: range)?.value,
                accessibilityLabel: EditorStrings.highlightTokenAccessibilityLabel
            ) { identifier in
                toggleHighlight(identifier)
            }

            swatchRow(
                title: EditorStrings.formatBarTextColorSectionTitle,
                tokens: SlateTextColorToken.allCases.map { ($0.rawValue, $0.foreground) },
                currentIdentifier: editorController.activeTextColor(in: block, range: range)?.value,
                accessibilityLabel: EditorStrings.textColorTokenAccessibilityLabel
            ) { identifier in
                toggleTextColor(identifier)
            }

            Divider()

            Button(role: .destructive) {
                editorController.removeAllFormatting(in: block, range: range)
            } label: {
                Text(EditorStrings.formatBarRemoveAllTitle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SlateColor.textPrimary)
        }
        .padding(Spacing.md)
        .frame(width: 224)
        .background(SlateColor.surfacePrimary)
    }

    /// Bascule : recliquer la pastille DEJA active la retire (docs/07, comportement
    /// bascule).
    private func toggleHighlight(_ identifier: String) {
        if editorController.activeHighlight(in: block, range: range)?.value == identifier {
            editorController.setHighlight(nil, in: block, range: range)
        } else {
            editorController.setHighlight(SlateHighlightColor(identifier), in: block, range: range)
        }
    }

    private func toggleTextColor(_ identifier: String) {
        if editorController.activeTextColor(in: block, range: range)?.value == identifier {
            editorController.setTextColor(nil, in: block, range: range)
        } else {
            editorController.setTextColor(SlateTextColor(identifier), in: block, range: range)
        }
    }

    private func swatchRow(
        title: String,
        tokens: [(identifier: String, color: Color)],
        currentIdentifier: String?,
        accessibilityLabel: @escaping (String) -> String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textSecondary)
            HStack(spacing: Spacing.xs) {
                ForEach(tokens, id: \.identifier) { token in
                    ColorSwatchButton(
                        color: token.color,
                        isSelected: currentIdentifier == token.identifier,
                        accessibilityLabel: accessibilityLabel(token.identifier)
                    ) {
                        onSelect(token.identifier)
                    }
                }
            }
        }
    }
}

/// Une pastille de 22 pt de la palette, avec sa COCHE quand selectionnee.
private struct ColorSwatchButton: View {
    let color: Color
    let isSelected: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color).frame(width: 22, height: 22)
                if isSelected {
                    Image(systemName: "checkmark")
                        .slateIconFont(11, weight: .bold, relativeTo: .caption)
                        .foregroundStyle(SlateColor.textPrimary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? EditorStrings.formatBarActiveValue : "")
    }
}

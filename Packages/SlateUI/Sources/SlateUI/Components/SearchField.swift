import SwiftUI

/// Champ de recherche generique (texte + bouton effacer), sans aucune notion de note.
/// `SlateFeatures` compose cette primitive pour la recherche de la liste de notes ; rien
/// n'empeche de la reutiliser ailleurs (base de donnees, IA...).
///
/// Spec E3 : "champ 22 pt surface.secondary, rayon 6" ; "La recherche focalisee porte le
/// meme anneau" -- meme geometrie EN INSET que `ListCell` (voir
/// `SlateGeometry.noteCellFocusRingInset`), pas l'anneau en offset de `SidebarRow`.
public struct SearchField: View {
    @Binding private var text: String
    private let placeholder: String
    private let clearButtonAccessibilityLabel: String

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(text: Binding<String>, placeholder: String, clearButtonAccessibilityLabel: String) {
        self._text = text
        self.placeholder = placeholder
        self.clearButtonAccessibilityLabel = clearButtonAccessibilityLabel
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .slateIconFont(SlateGeometry.searchFieldIconSize, relativeTo: .callout)
                .foregroundStyle(SlateColor.textSecondary)
            TextField(placeholder, text: $text)
                .slateFont(SlateFont.label)
                .textFieldStyle(.plain)
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .slateIconFont(SlateGeometry.searchFieldIconSize, relativeTo: .callout)
                        .foregroundStyle(SlateColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearButtonAccessibilityLabel)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: SlateGeometry.searchFieldHeight)
        .frame(maxWidth: .infinity)
        .background(SlateColor.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.searchFieldRadius, style: .continuous))
        .overlay(focusRingOverlay)
        .animation(
            SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion),
            value: text.isEmpty
        )
    }

    @ViewBuilder
    private var focusRingOverlay: some View {
        if isFocused {
            RoundedRectangle(cornerRadius: SlateGeometry.searchFieldRadius, style: .continuous)
                .inset(by: SlateGeometry.noteCellFocusRingInset)
                .stroke(SlateColor.focusRing, lineWidth: SlateGeometry.focusRingWidth)
        }
    }
}

#Preview("SearchField - vide / rempli (clair)") {
    VStack(spacing: 12) {
        SearchField(text: .constant(""), placeholder: "Rechercher", clearButtonAccessibilityLabel: "Effacer")
        SearchField(text: .constant("stencil"), placeholder: "Rechercher", clearButtonAccessibilityLabel: "Effacer")
    }
    .padding()
    .background(SlateColor.bgList)
}

#Preview("SearchField - sombre") {
    VStack(spacing: 12) {
        SearchField(text: .constant(""), placeholder: "Rechercher", clearButtonAccessibilityLabel: "Effacer")
        SearchField(text: .constant("stencil"), placeholder: "Rechercher", clearButtonAccessibilityLabel: "Effacer")
    }
    .padding()
    .background(SlateColor.bgList)
    .preferredColorScheme(.dark)
}

import SwiftUI

/// Item de liste (a puces ou numerotee), design/tokens.md §16, artboard G. Composant de
/// PRESENTATION pur : le contenu du texte est fourni par l'appelant, la renumerotation
/// et l'imbrication sont calculees en amont par `SlateEditor`.
public struct ListItemView<Content: View>: View {
    private let marker: SlateListMarker
    private let content: Content

    public init(_ marker: SlateListMarker, @ViewBuilder content: () -> Content) {
        self.marker = marker
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(marker.text)
                .slateFont(SlateFont.body)
                .monospacedDigit() // la colonne ne bouge pas au passage de 9 a 10
                .foregroundStyle(SlateColor.textSecondary)
                .frame(width: SlateGeometry.listMarkerWidth, alignment: marker.isOrdered ? .trailing : .center)
                .accessibilityHidden(true)
            content
                .slateFont(SlateFont.body)
                .foregroundStyle(SlateColor.textPrimary)
        }
        .padding(.leading, CGFloat(marker.level) * SlateGeometry.editorListIndentStep)
        .padding(.vertical, SlateGeometry.editorBlockSpacing / 2)
    }
}

#Preview("ListItemView - puces et numeros, clair") {
    ListItemGalleryPreview()
        .environment(\.colorScheme, .light)
}

#Preview("ListItemView - puces et numeros, sombre") {
    ListItemGalleryPreview()
        .environment(\.colorScheme, .dark)
}

private struct ListItemGalleryPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListItemView(.bullet(level: 0)) { Text("Premier niveau - puce ronde") }
            ListItemView(.bullet(level: 1)) { Text("Deuxieme niveau - chevron plein") }
            ListItemView(.bullet(level: 2)) { Text("Troisieme niveau - carre") }
            ListItemView(.ordered(index: 9, level: 0)) { Text("Neuf") }
            ListItemView(.ordered(index: 10, level: 0)) { Text("Dix - colonne stable") }
            ListItemView(.ordered(index: 1, level: 1)) { Text("Deuxieme niveau en lettres") }
            ListItemView(.ordered(index: 1, level: 2)) { Text("Troisieme niveau en romains") }
        }
        .padding(Spacing.lg)
        .frame(width: 480)
        .background(SlateColor.bgEditor)
    }
}

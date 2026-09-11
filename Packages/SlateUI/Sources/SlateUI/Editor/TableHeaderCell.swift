import SwiftUI

/// Cellule d'en-tete de tableau (design/tokens.md §16, artboard H) : 13 pt Semibold sur
/// `table.header.bg`, bordure `table.border`. Composant de PRESENTATION pur : le
/// contenu editable (`TextField`/binding sur le libelle de colonne) reste a la charge de
/// `SlateEditor`, qui seul connait le modele de tableau.
public struct TableHeaderCell<Content: View>: View {
    private let showsTrailingBorder: Bool
    private let content: Content

    public init(showsTrailingBorder: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsTrailingBorder = showsTrailingBorder
        self.content = content()
    }

    public var body: some View {
        content
            .slateFont(SlateFont.bodyEmphasis)
            .foregroundStyle(SlateColor.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SlateColor.tableHeaderBg)
            .overlay(alignment: .trailing) {
                if showsTrailingBorder {
                    Rectangle()
                        .fill(SlateColor.tableBorder)
                        .frame(width: SlateGeometry.strokeHairline)
                }
            }
    }
}

#Preview("TableHeaderCell - clair") {
    TableHeaderRowPreview()
        .environment(\.colorScheme, .light)
}

#Preview("TableHeaderCell - sombre") {
    TableHeaderRowPreview()
        .environment(\.colorScheme, .dark)
}

private struct TableHeaderRowPreview: View {
    var body: some View {
        HStack(spacing: 0) {
            TableHeaderCell { Text("Chantier") }
            TableHeaderCell { Text("Responsable") }
            TableHeaderCell(showsTrailingBorder: false) { Text("Livraison") }
        }
        .overlay(RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium).strokeBorder(SlateColor.tableBorder))
        .padding(Spacing.lg)
        .frame(width: 480)
        .background(SlateColor.bgEditor)
    }
}

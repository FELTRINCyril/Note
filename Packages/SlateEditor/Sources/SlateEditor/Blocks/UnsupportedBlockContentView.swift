import SlateModel
import SlateUI
import SwiftUI

/// Rendu de repli pour un `BlockType` dont l'apparence riche n'est pas encore
/// construite (voir `BlockRenderKind.unsupported`) : callout/table (Phase 8),
/// columnList/column (Phase 10), image/file/bookmark/embed/databaseView/pageLink.
///
/// Deliberement IDENTIFIABLE (glyphe + libelle + nom technique du type) plutot
/// qu'invisible ou plante : la consigne de la 5.1 est qu'aucun type de bloc ne doit
/// disparaitre silencieusement du rendu.
struct UnsupportedBlockContentView: View {
    let typeRawValue: String
    /// Libelle injecte par l'appelant (voir `NoteEditorStrings`), pas localise ici.
    let labelPrefix: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "square.dashed")
                .slateIconFont(SlateGeometry.sidebarIconSize, relativeTo: .caption)
                .foregroundStyle(SlateColor.textTertiary)
            Text("\(labelPrefix) \(typeRawValue)")
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textTertiary)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                .strokeBorder(
                    SlateColor.borderDefault,
                    style: StrokeStyle(lineWidth: SlateGeometry.strokeHairline, dash: [4, 3])
                )
        )
    }
}

#Preview("UnsupportedBlockContentView - clair") {
    UnsupportedBlockContentView(
        typeRawValue: BlockType.table.rawValue,
        labelPrefix: "Type de bloc pas encore pris en charge :"
    )
    .padding()
    .frame(width: 400)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("UnsupportedBlockContentView - sombre") {
    UnsupportedBlockContentView(
        typeRawValue: BlockType.table.rawValue,
        labelPrefix: "Type de bloc pas encore pris en charge :"
    )
    .padding()
    .frame(width: 400)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}

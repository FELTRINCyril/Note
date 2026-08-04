import SlateModel
import SlateUI
import SwiftUI

/// Item de liste a puces (`BlockType.bulletedList`), lecture seule. La puce est un
/// glyphe SF Symbols (`circle.fill`) plutot qu'un caractere Unicode "*" : la regle
/// `ascii_punctuation` du projet (voir `.swiftlint.yml`) interdit la puce Unicode dans
/// le code source, et un glyphe systeme suit nativement le Dynamic Type via
/// `slateIconFont`, ce qu'un caractere de police ne garantirait pas.
struct BulletedListItemContentView: View {
    let text: RichText?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: "circle.fill")
                .slateIconFont(Self.bulletGlyphSize, relativeTo: .body)
                .foregroundStyle(SlateColor.textSecondary)
                .accessibilityHidden(true)
            ParagraphBlockContentView(text: text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Item de liste a puces")
    }

    /// GAP DE TOKEN SIGNALE : aucun token `SlateGeometry` dedie a la taille d'une puce
    /// de liste dans l'editeur. `sidebarBadgeIconSize` (11 pt, glyphe rond de favori
    /// dans la sidebar) est le token existant le plus proche visuellement -- reutilise
    /// ici plutot que d'inventer une valeur, en attendant un token `editor.*` dedie.
    private static let bulletGlyphSize = SlateGeometry.sidebarBadgeIconSize
}

#Preview("BulletedListItemContentView - clair") {
    BulletedListItemContentView(text: RichText(plainText: "Premier item"))
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("BulletedListItemContentView - sombre") {
    BulletedListItemContentView(text: RichText(plainText: "Premier item"))
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

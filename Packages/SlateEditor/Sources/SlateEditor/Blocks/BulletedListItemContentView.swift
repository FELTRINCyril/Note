import SlateModel
import SlateUI
import SwiftUI

/// Item de liste a puces (`BlockType.bulletedList`), lecture seule. La puce est une
/// forme DESSINEE (`Circle()`) plutot qu'un caractere Unicode "*" (la regle
/// `ascii_punctuation` du projet, voir `.swiftlint.yml`, interdit la puce Unicode dans
/// le code source) ou un glyphe SF Symbol : `list.bulletSize` (design/tokens.md §16)
/// est un DIAMETRE visuel de 6 pt, pas une taille de police -- la boite de dessin
/// interne d'un glyphe `circle.fill` ne remplit pas sa taille de police nominale, donc
/// `slateIconFont` produirait un cercle plus petit que le diametre demande par la spec.
struct BulletedListItemContentView: View {
    let text: RichText?

    /// Diametre de la puce, mis a l'echelle Dynamic Type directement sur le `frame` de
    /// la forme dessinee (`SlateGeometry.listBulletSize`, voir sa documentation).
    @ScaledMetric(relativeTo: .body) private var bulletDiameter = SlateGeometry.listBulletSize

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Circle()
                .fill(SlateColor.textSecondary)
                .frame(width: bulletDiameter, height: bulletDiameter)
                .accessibilityHidden(true)
            ParagraphBlockContentView(text: text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Item de liste a puces")
    }
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

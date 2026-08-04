import SlateModel
import SlateUI
import SwiftUI

/// Item de liste a cocher (`BlockType.todo`), lecture seule : la case affichee reflete
/// `BlockAttributes.isChecked`, mais n'est pas interactive dans cette phase (cocher/
/// decocher au clic est une capacite d'EDITION, hors perimetre 5.1 -- voir la regle
/// d'honnetete d'interface du projet : un controle qui a l'air cliquable sans agir ne
/// doit pas etre expose. Le glyphe est donc rendu comme un simple `Image`, jamais un
/// `Button`/`Toggle`).
struct TodoItemContentView: View {
    let text: RichText?
    let isChecked: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .slateIconFont(SlateGeometry.sidebarIconSize, relativeTo: .body)
                .foregroundStyle(isChecked ? SlateColor.accentDefault : SlateColor.textSecondary)
                .accessibilityHidden(true)
            ParagraphBlockContentView(text: text, isStrikethrough: isChecked)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isChecked ? "Tache cochee" : "Tache non cochee")
    }
}

#Preview("TodoItemContentView - clair") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        TodoItemContentView(text: RichText(plainText: "A faire"), isChecked: false)
        TodoItemContentView(text: RichText(plainText: "Fait"), isChecked: true)
    }
    .padding()
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("TodoItemContentView - sombre") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        TodoItemContentView(text: RichText(plainText: "A faire"), isChecked: false)
        TodoItemContentView(text: RichText(plainText: "Fait"), isChecked: true)
    }
    .padding()
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}

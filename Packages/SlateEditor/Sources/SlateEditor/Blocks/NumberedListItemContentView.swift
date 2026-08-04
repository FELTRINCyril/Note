import SlateModel
import SlateUI
import SwiftUI

/// Item de liste numerotee (`BlockType.numberedList`), lecture seule. `rank` (1-based)
/// est calcule par `BlockOrdering.numberedListRank(of:among:)`, pas par cette vue :
/// elle se contente d'afficher un entier deja determine, testable sans SwiftUI.
struct NumberedListItemContentView: View {
    let text: RichText?
    let rank: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("\(rank).")
                .slateFont(SlateFont.body)
                .foregroundStyle(SlateColor.textSecondary)
                .monospacedDigit()
                .accessibilityHidden(true)
            ParagraphBlockContentView(text: text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Item \(rank) de liste numerotee")
    }
}

#Preview("NumberedListItemContentView - clair") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        NumberedListItemContentView(text: RichText(plainText: "Premier item"), rank: 1)
        NumberedListItemContentView(text: RichText(plainText: "Deuxieme item"), rank: 2)
    }
    .padding()
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("NumberedListItemContentView - sombre") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        NumberedListItemContentView(text: RichText(plainText: "Premier item"), rank: 1)
        NumberedListItemContentView(text: RichText(plainText: "Deuxieme item"), rank: 2)
    }
    .padding()
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}

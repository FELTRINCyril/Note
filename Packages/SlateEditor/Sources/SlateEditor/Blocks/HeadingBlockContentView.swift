import SlateModel
import SlateUI
import SwiftUI

/// Rendu en lecture seule d'un titre (`heading1` a `heading6`). Voir `HeadingStyle`
/// pour le mappage niveau -> `SlateFont` (et le gap de tokens signale la-bas).
struct HeadingBlockContentView: View {
    let text: RichText?
    let level: Int

    var body: some View {
        Text(text?.attributedString ?? AttributedString())
            .slateFont(HeadingStyle.font(forLevel: level))
            .foregroundStyle(SlateColor.textPrimary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("HeadingBlockContentView - clair") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        ForEach(1...6, id: \.self) { level in
            HeadingBlockContentView(text: RichText(plainText: "Titre de niveau \(level)"), level: level)
        }
    }
    .padding()
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("HeadingBlockContentView - sombre") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        ForEach(1...6, id: \.self) { level in
            HeadingBlockContentView(text: RichText(plainText: "Titre de niveau \(level)"), level: level)
        }
    }
    .padding()
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}

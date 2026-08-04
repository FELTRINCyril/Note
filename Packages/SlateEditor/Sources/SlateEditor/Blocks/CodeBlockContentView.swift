import SlateModel
import SlateUI
import SwiftUI

/// Bloc de code (`BlockType.code`), lecture seule : fond `SlateColor.
/// codeBlockBackground`, police a chasse fixe. La coloration syntaxique par langage
/// (`BlockAttributes.language`) est hors perimetre de la 5.1 (Phase 8) : le langage
/// n'est pas encore affiche.
struct CodeBlockContentView: View {
    let text: RichText?

    var body: some View {
        Text(text?.plainText ?? "")
            .slateFont(SlateFont.body)
            .fontDesign(.monospaced)
            .foregroundStyle(SlateColor.textPrimary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                    .fill(SlateColor.codeBlockBackground)
            )
            .accessibilityLabel("Bloc de code")
    }
}

#Preview("CodeBlockContentView - clair") {
    CodeBlockContentView(text: RichText(plainText: "let x = 1\nprint(x)"))
        .padding()
        .frame(width: 400)
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("CodeBlockContentView - sombre") {
    CodeBlockContentView(text: RichText(plainText: "let x = 1\nprint(x)"))
        .padding()
        .frame(width: 400)
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

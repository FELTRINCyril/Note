import SwiftUI

/// Barre d'outils du bloc de code (design/tokens.md §16, artboard E) : selecteur de
/// langage + bouton copier, n'apparaissant qu'au survol ou au focus (a la charge de
/// l'appelant via `.opacity`/`chromeVisible`). Composant de PRESENTATION pur : l'etat
/// "code copie" (`didCopy`) et l'action de copie restent portes par `SlateEditor`, qui
/// seul a acces au contenu reel du bloc.
public struct CodeBlockToolbar: View {
    @Binding private var language: String
    private let languages: [String]
    private let didCopy: Bool
    private let onCopy: () -> Void

    public init(
        language: Binding<String>,
        languages: [String] = ["swift", "javascript", "python", "json", "text"],
        didCopy: Bool,
        onCopy: @escaping () -> Void
    ) {
        self._language = language
        self.languages = languages
        self.didCopy = didCopy
        self.onCopy = onCopy
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Picker(SlateUIStrings.codeBlockLanguage, selection: $language) {
                ForEach(languages, id: \.self) { language in
                    Text(language.capitalized).tag(language)
                }
            }
            .labelsHidden()
            .controlSize(.small)

            Button(action: onCopy) {
                Label(
                    didCopy ? SlateUIStrings.codeBlockCopied : SlateUIStrings.codeBlockCopy,
                    systemImage: didCopy ? "checkmark" : "doc.on.doc"
                )
                    .slateFont(SlateFont.label)
                    // Le succes n'est jamais porte par la seule couleur : la coche et le
                    // mot changent aussi (artboard E).
                    .foregroundStyle(didCopy ? SlateColor.semanticSuccess : SlateColor.textPrimary)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut("c", modifiers: [.control, .option]) // atteignable sans survol
        }
        .padding(Spacing.sm)
    }
}

#Preview("CodeBlockToolbar - clair") {
    CodeBlockToolbarPreview()
        .environment(\.colorScheme, .light)
}

#Preview("CodeBlockToolbar - sombre") {
    CodeBlockToolbarPreview()
        .environment(\.colorScheme, .dark)
}

private struct CodeBlockToolbarPreview: View {
    @State private var language = "swift"

    var body: some View {
        CodeBlockToolbar(language: $language, didCopy: false, onCopy: {})
            .background(SlateColor.codeBlockBackground)
            .padding(Spacing.lg)
            .background(SlateColor.bgEditor)
    }
}

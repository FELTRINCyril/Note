import AppKit
import SlateModel
import SlateServices
import SlateUI
import SwiftUI

/// Bloc de code (`BlockType.code`), EDITABLE depuis la Phase 8 (docs/08, "Bloc de
/// code") : police mono (voir `RichTextEditingTextView.applyTypography(for:isChecked:)`),
/// fond dedie, coloration syntaxique (`SlateServices.SyntaxHighlighter`, appliquee au
/// niveau du `NSTextView` -- voir `RichTextEditingRepresentable+Rendering.swift`),
/// selecteur de langage et bouton copier (`CodeBlockToolbar`, `SlateUI`), visibles au
/// survol OU au focus du bloc.
///
/// ## Debordement horizontal (docs/08 : "jamais de retour a la ligne force")
/// `RichTextBlockView` est enveloppe dans un `ScrollView(.horizontal)` : le
/// `NSTextView` lui-meme ne retombe JAMAIS a la ligne pour ce type de bloc (voir
/// `RichTextEditingTextView+Typography.swift`, `applyWrapping(for:)`), sa largeur
/// NATURELLE (potentiellement superieure a celle du bloc) est remontee par
/// `intrinsicSize(forProposedWidth:)` -- c'est cette largeur que le `ScrollView` peut
/// alors faire defiler.
struct CodeBlockContentView: View {
    let block: Block
    let editorController: EditorController

    @State private var didCopy = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isHovering || isFocused {
                CodeBlockToolbar(
                    language: languageBinding,
                    languages: SyntaxLanguage.allCases.map(\.rawValue),
                    didCopy: didCopy,
                    onCopy: copyToPasteboard
                )
            }
            ScrollView(.horizontal, showsIndicators: true) {
                RichTextBlockView(block: block, editorController: editorController)
                    .padding(Spacing.sm)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                .fill(SlateColor.codeBlockBackground)
        )
        .onHover { isHovering = $0 }
    }

    private var isFocused: Bool {
        editorController.focusedBlockID == block.id
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { SyntaxLanguage.resolve(block.attributes.language).rawValue },
            set: { editorController.setCodeLanguage($0, in: block) }
        )
    }

    /// Copie le contenu BRUT du bloc (`RichText.plainText`, jamais le rendu colore --
    /// coller ailleurs doit produire du texte, pas une capture visuelle). Le succes
    /// n'est jamais porte par la seule couleur (`CodeBlockToolbar` change aussi
    /// l'icone/le mot, voir sa documentation) : une annonce VoiceOver explicite
    /// complete l'affordance pour les utilisateurs qui ne VOIENT pas ce changement.
    private func copyToPasteboard() {
        let plainText = block.text?.plainText ?? ""
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plainText, forType: .string)
        didCopy = true
        AccessibilityNotification.Announcement(EditorStrings.codeBlockCopyAccessibilityAnnouncement).post()
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            didCopy = false
        }
    }
}

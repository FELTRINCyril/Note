import SlateModel
import SlateUI
import SwiftUI

/// Contenu de la barre de formatage flottante (docs/07_typographie_formatage.md,
/// artboard P1 A) : menu de style (libelle = style courant du bloc), puis B/I/U/S/code/
/// surlignage/lien. Presentee par `FormatBarOverlay` (positionnement, jamais un
/// `.popover` -- voir sa documentation de tete).
struct FormatBarView: View {
    let block: Block
    let editorController: EditorController
    let range: RichTextRange

    @State private var isColorPopoverPresented = false
    @State private var isLinkPopoverPresented = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            styleMenu

            Divider().frame(height: 18)

            FormatBarButton(
                systemImage: "bold",
                accessibilityLabel: EditorStrings.formatBarBoldLabel,
                isActive: editorController.isMarkActive(.bold, in: block, range: range)
            ) {
                editorController.toggleMark(.bold, in: block, range: range)
            }
            FormatBarButton(
                systemImage: "italic",
                accessibilityLabel: EditorStrings.formatBarItalicLabel,
                isActive: editorController.isMarkActive(.italic, in: block, range: range)
            ) {
                editorController.toggleMark(.italic, in: block, range: range)
            }
            FormatBarButton(
                systemImage: "underline",
                accessibilityLabel: EditorStrings.formatBarUnderlineLabel,
                isActive: editorController.isMarkActive(.underline, in: block, range: range)
            ) {
                editorController.toggleMark(.underline, in: block, range: range)
            }
            FormatBarButton(
                systemImage: "strikethrough",
                accessibilityLabel: EditorStrings.formatBarStrikethroughLabel,
                isActive: editorController.isMarkActive(.strikethrough, in: block, range: range)
            ) {
                editorController.toggleMark(.strikethrough, in: block, range: range)
            }
            FormatBarButton(
                systemImage: "curlybraces",
                accessibilityLabel: EditorStrings.formatBarInlineCodeLabel,
                isActive: editorController.isMarkActive(.inlineCode, in: block, range: range)
            ) {
                editorController.toggleMark(.inlineCode, in: block, range: range)
            }

            FormatBarButton(
                systemImage: "highlighter",
                accessibilityLabel: EditorStrings.formatBarHighlightLabel,
                isActive: editorController.activeHighlight(in: block, range: range) != nil
                    || editorController.activeTextColor(in: block, range: range) != nil
            ) {
                isColorPopoverPresented = true
            }
            .popover(isPresented: $isColorPopoverPresented, arrowEdge: .bottom) {
                FormatColorPopoverView(block: block, editorController: editorController, range: range)
            }

            // Desactive sur une plage qui couvre plusieurs liens differents
            // (`currentLink` retourne alors `nil` MEME si des liens existent -- voir sa
            // documentation) : pas de distinction visuelle possible entre "aucun lien"
            // et "liens multiples" ici, les deux se comportent en creation si actionnes,
            // ce qui reste honnete (le popover affichera alors le champ de creation).
            FormatBarButton(
                systemImage: "link",
                accessibilityLabel: EditorStrings.formatBarLinkLabel,
                isActive: editorController.currentLink(in: block, range: range) != nil
            ) {
                isLinkPopoverPresented = true
            }
            .popover(isPresented: $isLinkPopoverPresented, arrowEdge: .bottom) {
                LinkEditorPopoverView(
                    block: block,
                    editorController: editorController,
                    range: range,
                    selectedText: selectedPlainText,
                    onDismiss: { isLinkPopoverPresented = false }
                )
            }
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: SlateGeometry.formatBarHeight)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: SlateGeometry.formatBarRadius, style: .continuous)
        )
        .shadow(
            color: SlateColor.elevationMediumShadow,
            radius: SlateGeometry.formatBarShadowRadius,
            y: SlateGeometry.formatBarShadowY
        )
        .onChange(of: editorController.linkEditRequest) { _, newValue in
            // Cmd+K (`RichTextEditingTextView.handleFormattingKeyEquivalent`) ouvre le
            // popover de lien via `EditorController.requestLinkEditor`, sans passer par
            // le bouton -- cette barre doit donc REAGIR a la demande, pas seulement la
            // servir sur clic direct.
            guard let newValue, newValue.blockID == block.id, newValue.range == range else { return }
            isLinkPopoverPresented = true
        }
    }

    private var styleMenu: some View {
        Menu {
            Button(EditorStrings.formatBarStyleParagraph) { editorController.convertBlock(block, to: .paragraph) }
            ForEach(1...6, id: \.self) { level in
                Button(EditorStrings.formatBarStyleHeading(level)) {
                    editorController.convertBlock(block, to: headingType(for: level))
                }
            }
        } label: {
            Text(currentStyleLabel)
                .slateFont(SlateFont.label)
        }
        .menuStyle(.borderlessButton)
        .frame(minWidth: 72)
    }

    private var currentStyleLabel: String {
        switch BlockRenderRouting.kind(for: block.type) {
        case let .heading(level): EditorStrings.formatBarStyleHeading(level)
        default: EditorStrings.formatBarStyleParagraph
        }
    }

    private func headingType(for level: Int) -> BlockType {
        switch level {
        case 1: .heading1
        case 2: .heading2
        case 3: .heading3
        case 4: .heading4
        case 5: .heading5
        default: .heading6
        }
    }

    /// Texte reellement selectionne (`range`), pour le titre "Lier <texte>" du popover
    /// de creation de lien (artboard P1 C).
    private var selectedPlainText: String {
        guard let text = block.text else { return "" }
        let characters = Array(text.plainText)
        let lower = min(range.lowerBound.characters, characters.count)
        let upper = min(range.upperBound.characters, characters.count)
        guard lower <= upper else { return "" }
        return String(characters[lower..<upper])
    }
}

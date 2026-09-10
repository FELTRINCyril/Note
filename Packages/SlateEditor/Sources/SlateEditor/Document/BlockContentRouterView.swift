import SlateModel
import SlateUI
import SwiftUI

/// Routeur de bloc : associe un `Block` a son apparence (`BlockRenderKind`, voir
/// `BlockRenderRouting`) et instancie la vue de contenu correspondante.
///
/// Ce `switch` est exhaustif sur `BlockRenderKind` (lui-meme construit de facon
/// exhaustive sur `BlockType`, voir `BlockRenderRouting.kind(for:)`) : le compilateur
/// empeche d'oublier un cas si `BlockRenderKind` gagne un cas plus tard.
///
/// ## Continuite avec l'edition (5.2)
/// Seul `.paragraph` est desormais EDITABLE (`RichTextBlockView`, TextKit 2) : c'est le
/// seul type demande par la sous-etape 5.2 (docs/05_editeur_blocs.md). Tous les autres
/// cas restent en lecture seule -- la 5.5 (conversion de type) et les phases
/// ulterieures des blocs riches remplaceront les autres cas au meme endroit, un a un,
/// sans toucher a `BlockTreeView` ni `NoteDocumentView` qui appellent ce routeur.
struct BlockContentRouterView: View {
    let block: Block
    let numberedRank: Int
    let strings: NoteEditorStrings
    /// Coordinateur de cycle de vie des blocs (sous-etape 5.3). Transite simplement
    /// jusqu'a `RichTextBlockView` (seul type qui en a besoin, pour piloter
    /// focus/caret/insertion/fusion) : ignore par tous les autres cas, encore en
    /// lecture seule a ce stade de la Phase 5.
    let editorController: EditorController

    var body: some View {
        switch BlockRenderRouting.kind(for: block.type) {
        case .paragraph, .heading:
            // Titres EDITABLES depuis la Phase 7 (docs/07_typographie_formatage.md,
            // point 6) : `RichTextBlockView` derive sa typographie du `BlockType` reel
            // du bloc (voir `RichTextEditingTextView.applyTypography(for:)`), plus
            // besoin de `HeadingBlockContentView` (lecture seule, conserve pour ses
            // previews mais plus route ici).
            RichTextBlockView(block: block, editorController: editorController)
        case .divider:
            DividerBlockContentView()
        case .bulletedListItem:
            BulletedListItemContentView(text: block.text)
        case .numberedListItem:
            NumberedListItemContentView(text: block.text, rank: numberedRank)
        case .todoItem:
            TodoItemContentView(text: block.text, isChecked: block.attributes.isChecked)
        case .quote:
            QuoteBlockContentView(text: block.text)
        case .code:
            CodeBlockContentView(text: block.text)
        case let .unsupported(type):
            UnsupportedBlockContentView(typeRawValue: type.rawValue, labelPrefix: strings.unsupportedBlockLabelPrefix)
        }
    }
}

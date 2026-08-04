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
/// Ce routeur ne connait PAS le concept de focus/edition : il ne fait que choisir un
/// `Content*View` en lecture seule a partir du type. Quand la 5.2 introduira
/// `RichTextBlockView` (TextKit 2), le remplacement se fera ICI, cas par cas
/// (`.paragraph`, `.heading`... deviendront editables un a un), sans toucher a
/// `BlockTreeView` ni `NoteDocumentView` qui l'appellent : c'est le point d'extension
/// prevu par l'architecture demandee par Cyril (SlateEditor, decision d'architecture
/// d'edition, option 2 -- `RichTextBlockView` par bloc).
struct BlockContentRouterView: View {
    let block: Block
    let numberedRank: Int
    let strings: NoteEditorStrings

    var body: some View {
        switch BlockRenderRouting.kind(for: block.type) {
        case .paragraph:
            ParagraphBlockContentView(text: block.text)
        case let .heading(level):
            HeadingBlockContentView(text: block.text, level: level)
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

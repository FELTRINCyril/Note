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
/// ## Continuite avec l'edition (5.2, 7, 8)
/// Depuis la Phase 8, TOUS les types de bloc rendus (hormis `.divider`, sans texte) sont
/// EDITABLES via `RichTextBlockView` (TextKit 2) : les items de liste, la citation et le
/// bloc code enveloppent desormais `RichTextBlockView` dans le composant de presentation
/// `SlateUI` correspondant (`ListItemView`/`ChecklistItemView`/`QuoteBlockView`),
/// exactement comme les titres depuis la Phase 7 -- meme motif, applique un cran plus
/// loin. Le tableau (`.table`) et le callout (`.callout`) sont routes vers leurs
/// propres vues dediees (`TableBlockContentView`/`CalloutBlockContentView`).
struct BlockContentRouterView: View {
    let block: Block
    let numberedRank: Int
    /// Profondeur d'imbrication de `block` (`BlockOrdering.indentLevel(of:)`, calculee
    /// par `BlockTreeView`) : utilisee UNIQUEMENT par les 3 types d'item de liste, pour
    /// choisir la forme de puce/le style de numerotation cyclique
    /// (`SlateListMarker`/`ChecklistItemView`) ET porter leur propre indentation -- voir
    /// la documentation de `BlockTreeView` pour pourquoi ces types n'ont pas EN PLUS
    /// l'indentation generique du conteneur.
    let indentLevel: Int
    let strings: NoteEditorStrings
    /// Coordinateur de cycle de vie des blocs (sous-etape 5.3). Transite jusqu'a chaque
    /// vue de contenu EDITABLE (toutes, hormis `.divider`), qui l'utilise pour piloter
    /// focus/caret/insertion/fusion et les actions dediees (case a cocher, langage de
    /// code, icone de callout, structure de tableau -- voir
    /// `EditorController+SpecialBlocks.swift`/`+Table.swift`).
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
            DividerBlockView()
        case .bulletedListItem:
            BulletedListItemContentView(block: block, editorController: editorController, level: indentLevel)
        case .numberedListItem:
            NumberedListItemContentView(
                block: block, editorController: editorController, rank: numberedRank, level: indentLevel
            )
        case .todoItem:
            TodoItemContentView(block: block, editorController: editorController, level: indentLevel)
        case .quote:
            QuoteBlockContentView(block: block, editorController: editorController)
        case .code:
            CodeBlockContentView(block: block, editorController: editorController)
        case .callout:
            CalloutBlockContentView(block: block, editorController: editorController)
        case .table:
            TableBlockContentView(block: block, editorController: editorController)
        case .image:
            ImageBlockContentView(block: block, editorController: editorController)
        case .file:
            FileBlockContentView(block: block, editorController: editorController)
        case let .unsupported(type):
            UnsupportedBlockContentView(typeRawValue: type.rawValue, labelPrefix: strings.unsupportedBlockLabelPrefix)
        }
    }
}

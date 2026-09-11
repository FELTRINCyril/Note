import SlateModel
import SlateUI
import SwiftUI

/// Rangee de colonnes (`BlockType.columnList`, Phase 10, artboard J de
/// `Slate P1 - Formatage & blocs.dc.html`). Delegue tout le chrome/redimensionnement a
/// `ColumnsBlockView` (`SlateUI`, pur quant au contenu) : le seul role de cette vue est
/// de brancher, POUR CHAQUE colonne, une pile verticale des vrais `Block` qu'elle
/// porte -- chacun avec son propre `BlockContainer` complet (chrome, selection, focus
/// clavier), exactement comme au niveau racine du document (voir `NoteDocumentView`).
///
/// `column` (l'enfant direct de `block`) n'a lui-meme AUCUN rendu propre (voir
/// `BlockRenderKind.unsupported`, cas `.column`) : cette vue lit directement ses
/// `children` sans jamais le faire router par `BlockContentRouterView`.
struct ColumnListBlockContentView: View {
    let block: Block
    let strings: NoteEditorStrings
    let editorController: EditorController
    let rangePositions: [UUID: SlateBlockRangePosition]

    private var columns: [Block] { BlockOrdering.children(of: block) }

    private var fractionsBinding: Binding<[CGFloat]> {
        Binding(
            get: { ColumnStructure.widthFractions(for: block) },
            set: { editorController.setColumnFractions($0, in: block) }
        )
    }

    var body: some View {
        ColumnsBlockView(fractions: fractionsBinding) { index in
            columnContent(at: index)
        }
        .padding(.vertical, SlateGeometry.decoratedBlockSpacing)
    }

    @ViewBuilder
    private func columnContent(at index: Int) -> some View {
        if columns.indices.contains(index) {
            let column = columns[index]
            let children = BlockOrdering.children(of: column)
            // `LazyVStack` : meme raison de perf que `NoteDocumentView`/`BlockTreeView`
            // (une colonne peut elle aussi porter un grand nombre de blocs).
            LazyVStack(alignment: .leading, spacing: SlateGeometry.editorBlockSpacing) {
                ForEach(children, id: \.id) { child in
                    BlockTreeView(
                        block: child,
                        siblings: children,
                        indentLevel: 0,
                        strings: strings,
                        editorController: editorController,
                        rangePositions: rangePositions
                    )
                    .id(child.id)
                }
            }
        } else {
            EmptyView()
        }
    }
}

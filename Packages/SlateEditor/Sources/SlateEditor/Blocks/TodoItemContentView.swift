import SlateModel
import SlateUI
import SwiftUI

/// Item de liste a cocher (`BlockType.todo`), EDITABLE depuis la Phase 8 (docs/08,
/// "Case a cocher fonctionnelle... persistee"). La case est desormais un vrai controle
/// (`ChecklistItemView`, `SlateUI`), plus un simple glyphe en lecture seule -- son
/// `Binding` passe par `EditorController.setChecked(_:in:)`, seul point d'ecriture de
/// `BlockAttributes.isChecked` (persistance immediate, pas de debounce -- meme motif que
/// les autres actions ponctuelles de menu). Le texte barre/estompe une fois coche est
/// applique au NIVEAU DU `NSTextView` lui-meme (voir `RichTextEditingTextView.
/// applyTypography(for:isChecked:)` et `RichTextEditingRepresentable.Coordinator.apply(
/// _:to:)`) : les modificateurs SwiftUI `.strikethrough`/`.foregroundStyle` de
/// `ChecklistItemView` n'ont aucun effet sur le rendu INTERNE d'un `NSViewRepresentable`.
struct TodoItemContentView: View {
    let block: Block
    let editorController: EditorController
    let level: Int

    var body: some View {
        ChecklistItemView(isDone: isCheckedBinding, level: level) {
            RichTextBlockView(block: block, editorController: editorController)
        }
    }

    private var isCheckedBinding: Binding<Bool> {
        Binding(
            get: { block.attributes.isChecked },
            set: { editorController.setChecked($0, in: block) }
        )
    }
}

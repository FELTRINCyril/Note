import AppKit
import os
import SlateModel
import SlateUI
import SwiftData
import SwiftUI

/// Bloc paragraphe EDITABLE (docs/05_editeur_blocs.md, sous-etape 5.2) : `NSViewRepresentable`
/// autour d'un `NSTextView` TextKit 2 (`RichTextEditingTextView`), livrable central de
/// cette sous-etape (decision d'architecture de Phase 5, option 2 -- voir ce doc).
///
/// ## Contrat avec le modele
/// Lit et ecrit `Block.text` (`RichText`) via son accesseur, JAMAIS en reconstruisant un
/// `RichText` a partir de texte brut (`RichText.init(plainText:)`) : cela detruirait les
/// attributs inline que la Phase 7 exploitera. La conversion passe systematiquement par
/// `RichText.init(attributedString:)` a partir du contenu reel de l'`NSTextView`.
///
/// ## Sauvegarde : ce qui est synchrone, ce qui est debounce
/// `block.text` est ecrit en memoire a CHAQUE frappe (`Coordinator.textDidChange`) :
/// c'est un simple encodage JSON d'un paragraphe, documente comme negligeable par
/// `Block.textData`. Seules les operations couteuses -- `Note.refreshDerivedText()`,
/// `Note.modifiedAt` et l'ecriture reelle sur disque (`ModelContext.save()`) -- passent
/// par `BlockSaveDebouncer` et ne s'executent qu'au repos (600 ms sans frappe) ou au
/// FLUSH explicite.
///
/// ## Flush garanti (aucune frappe perdue)
/// Le flush est declenche a TROIS moments (docs/05_editeur_blocs.md, sous-etape 5.2,
/// point 3) :
/// 1. perte de focus du bloc (`Coordinator.textDidEndEditing`) ;
/// 2. la vue est retiree de la hierarchie (`dismantleNSView`) -- couvre a la fois la
///    fermeture de la note en cours ET le changement de note (`NoteDetailColumnView`
///    reconstruit l'arbre de blocs pour la nouvelle note, ce qui fait disparaitre du
///    `ForEach` tous les blocs de l'ancienne, donc demonte leur `RichTextBlockView`) ;
/// 3. transitivement, la fermeture de la fenetre/l'app, SI SwiftUI demonte la hierarchie
///    avant la sortie du processus -- comportement standard mais non garanti a 100 % par
///    ce code seul. En filet de securite : `block.text` est deja a jour en memoire au
///    moment ou l'autosave par defaut de `ModelContext` (active tant qu'il n'est pas
///    explicitement desactive) se declenche sur ses propres evenements systeme
///    (perte du statut de fenetre cle, passage de l'app en arriere-plan...), independamment
///    de ce debounce.
public struct RichTextBlockView: View {
    private let block: Block
    private let editorController: EditorController

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(block: Block, editorController: EditorController) {
        self.block = block
        self.editorController = editorController
    }

    public var body: some View {
        RichTextEditingRepresentable(
            block: block,
            editorController: editorController,
            modelContext: modelContext,
            reduceMotion: reduceMotion
        )
    }
}

/// Contenu commun aux previews : `RichTextBlockView` lit `@Environment(\.modelContext)`
/// (pour la sauvegarde debouncee), un conteneur SwiftData en memoire est donc requis --
/// contrairement aux previews en lecture seule de la Phase 5.1, qui n'en avaient pas
/// besoin. Pas de `try!`/force-unwrap (CLAUDE.md §5) : un echec de creation du
/// conteneur (improbable en memoire) retombe sur un texte de diagnostic plutot qu'un
/// crash de preview.
private struct RichTextBlockPreviewHost: View {
    let text: RichText?

    var body: some View {
        let note = Note(title: "Apercu")
        let block = Block(type: .paragraph, text: text, note: note)
        note.blocks = [block]
        return Group {
            if let container = try? SlateContainer.make(inMemory: true) {
                RichTextBlockView(block: block, editorController: EditorController(note: note))
                    .modelContainer(container)
            } else {
                Text("Conteneur SwiftData indisponible pour cette preview")
            }
        }
        .padding()
        .frame(width: 500)
        .background(SlateColor.bgEditor)
    }
}

#Preview("RichTextBlockView - clair") {
    RichTextBlockPreviewHost(text: RichText(plainText: "Un bloc editable, TextKit 2."))
        .environment(\.colorScheme, .light)
}

#Preview("RichTextBlockView - vide") {
    // Bloc vide isole : AUCUN placeholder ici, il n'est peint que par `BlockContainer`
    // (voir `BlockTreeView`), pas par `RichTextBlockView` lui-meme. Cette preview verifie
    // uniquement que le NSTextView reste utilisable (caret visible) sans contenu.
    RichTextBlockPreviewHost(text: nil)
        .environment(\.colorScheme, .dark)
}

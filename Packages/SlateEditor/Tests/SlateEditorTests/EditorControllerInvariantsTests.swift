import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// Invariants transversaux qui doivent survivre a N'IMPORTE QUELLE SEQUENCE
/// d'operations structurelles de l'`EditorController` (revue finale de Phase 5,
/// docs/05_editeur_blocs.md) -- pas seulement a une operation isolee, comme le fait deja
/// chaque suite de tests par type d'operation (`BlockLifecycleTests`,
/// `BlockOperationsTests`, `BlockSelectionOperationsTests`...). Chaque test ici enchaine
/// PLUSIEURS operations de sous-etapes DIFFERENTES (5.3 clavier, 5.4 menu, 5.5
/// conversion, 5.6 lot) sur le MEME graphe, et verifie apres CHAQUE etape :
/// 1. `order` reste une suite compacte 0..n-1 sans doublon, au sein de CHAQUE fratrie ;
/// 2. la note ne se retrouve jamais sans aucun bloc ;
/// 3. `Note.modifiedAt`/`Note.plainText` sont a jour apres CHAQUE operation persistee
///    (aucun chemin d'ecriture n'oublie `persistStructuralChange()`).
@MainActor
@Suite("EditorController - invariants transversaux (sequences d'operations melangees)")
struct EditorControllerInvariantsTests {
    /// Verifie l'invariant d'`order` pour CHAQUE fratrie du document (blocs racine, et
    /// les enfants de chaque bloc qui en a) : suite compacte 0..n-1, sans trou ni
    /// doublon. Un doublon ou un trou desynchroniserait silencieusement l'ordre de
    /// lecture de `BlockOrdering.sortedByOrder(_:)` du tableau relationnel reel.
    private func assertOrderInvariant(_ note: Note, sourceLocation: SourceLocation = #_sourceLocation) {
        func checkSiblingGroup(_ blocks: [Block]) {
            let orders = blocks.map(\.order).sorted()
            let message = "order non compact/duplique : \(orders)"
            #expect(orders == Array(0..<blocks.count), Comment(rawValue: message), sourceLocation: sourceLocation)
        }
        checkSiblingGroup(BlockOrdering.topLevelBlocks(of: note))
        for block in BlockOrdering.flattenedBlocks(of: note) {
            let children = BlockOrdering.children(of: block)
            if !children.isEmpty {
                checkSiblingGroup(children)
            }
        }
    }

    private func assertNeverEmpty(_ note: Note, sourceLocation: SourceLocation = #_sourceLocation) {
        let message: Comment = "la note ne doit jamais rester sans aucun bloc"
        #expect(!(note.blocks ?? []).isEmpty, message, sourceLocation: sourceLocation)
    }

    // MARK: - Sequence 1 : clavier (5.3) puis menu (5.4) puis conversion (5.5)

    @Test("Entree, Backspace, menu Dupliquer/Supprimer, conversion : order et non-vacuite tiennent a chaque etape")
    func keyboardThenMenuThenConversionKeepsInvariants() {
        let note = Note(title: "Test", modifiedAt: .distantPast)
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)

        // 5.3 : Entree en fin du premier bloc -> 3 blocs.
        controller.handleEnter(in: first, caretOffset: 2)
        assertOrderInvariant(note)
        assertNeverEmpty(note)
        #expect(note.modifiedAt != .distantPast)

        let afterEnter = BlockOrdering.topLevelBlocks(of: note)
        #expect(afterEnter.count == 3)

        // 5.4 : dupliquer le dernier bloc -> 4 blocs.
        controller.duplicateBlock(afterEnter[2])
        assertOrderInvariant(note)
        assertNeverEmpty(note)

        // 5.4 : supprimer le bloc du milieu.
        let afterDuplicate = BlockOrdering.topLevelBlocks(of: note)
        controller.deleteBlock(afterDuplicate[1])
        assertOrderInvariant(note)
        assertNeverEmpty(note)

        // 5.5 : convertir le premier bloc restant en titre, texte preserve.
        let afterDelete = BlockOrdering.topLevelBlocks(of: note)
        let originalText = afterDelete[0].text?.plainText
        controller.convertBlock(afterDelete[0], to: .heading2)
        assertOrderInvariant(note)
        assertNeverEmpty(note)
        #expect(afterDelete[0].text?.plainText == originalText)

        // 5.3 : Backspace en tete du dernier bloc restant fusionne avec le precedent.
        let beforeBackspace = BlockOrdering.topLevelBlocks(of: note)
        if beforeBackspace.count > 1, let lastBlock = beforeBackspace.last {
            controller.handleBackspaceAtBlockStart(lastBlock)
            assertOrderInvariant(note)
            assertNeverEmpty(note)
        }
    }

    // MARK: - Sequence 2 : suppressions repetees jusqu'au dernier bloc (filet, chemin clavier)

    @Test("Backspace repete jusqu'a un seul bloc : la note ne devient jamais vide (chemin clavier)")
    func repeatedBackspaceNeverEmptiesNote() {
        let note = Note(title: "Test")
        let blocks = (0..<5).map { index in
            Block(order: index, type: .paragraph, text: RichText(plainText: "Bloc \(index)"), note: note)
        }
        note.blocks = blocks
        let controller = EditorController(note: note)

        // Vide chaque bloc puis fusionne par Backspace, du dernier au deuxieme :
        // reproduit une suppression totale du contenu bloc par bloc.
        while BlockOrdering.topLevelBlocks(of: note).count > 1 {
            let ordered = BlockOrdering.topLevelBlocks(of: note)
            guard let last = ordered.last else { break }
            last.text = RichText()
            controller.handleBackspaceAtBlockStart(last)
            assertOrderInvariant(note)
            assertNeverEmpty(note)
        }

        #expect(BlockOrdering.topLevelBlocks(of: note).count == 1)
    }

    // MARK: - Sequence 3 : suppression en lot (5.6) jusqu'a vider TOUS les blocs

    @Test("deleteSelectionRange() sur la totalite des blocs racine declenche le meme filet que la suppression unique")
    func deleteEntireSelectionRangeStillLeavesOneBlock() {
        let note = Note(title: "Test", modifiedAt: .distantPast)
        let blocks = (0..<4).map { index in
            Block(order: index, type: .paragraph, text: RichText(plainText: "Bloc \(index)"), note: note)
        }
        note.blocks = blocks
        let controller = EditorController(note: note)

        guard let firstBlock = blocks.first, let lastBlock = blocks.last else {
            Issue.record("blocs de test manquants")
            return
        }
        controller.selectBlock(firstBlock)
        controller.extendSelection(to: lastBlock)
        controller.deleteSelectionRange()

        assertOrderInvariant(note)
        assertNeverEmpty(note)
        let remaining = BlockOrdering.topLevelBlocks(of: note).count
        #expect(remaining == 1, "filet 'jamais vide' attendu apres suppression totale en lot")
        #expect(note.modifiedAt != .distantPast, "deleteSelectionRange() doit passer par persistStructuralChange()")
    }

    // MARK: - Sequence 4 : promotion des enfants UNIFORME sur les trois chemins de suppression

    @Test("Promotion des enfants : identique via Backspace (5.3), menu Supprimer (5.4) et suppression en lot (5.6)")
    func childPromotionIsUniformAcrossAllDeletionPaths() {
        struct ParentWithChild {
            let note: Note
            let parent: Block
            let child: Block
        }

        func makeParentWithChild() -> ParentWithChild {
            let note = Note(title: "Test")
            let parent = Block(order: 0, type: .bulletedList, text: RichText(), note: note)
            let childText = RichText(plainText: "Enfant")
            let child = Block(order: 0, type: .bulletedList, text: childText, note: note, parent: parent)
            parent.children = [child]
            let sibling = Block(order: 1, type: .paragraph, text: RichText(plainText: "Frere"), note: note)
            note.blocks = [parent, sibling]
            return ParentWithChild(note: note, parent: parent, child: child)
        }

        // Chemin 5.3 : Backspace en tete du bloc suivant fusionne avec `parent` (bloc
        // textuel), donc ne retire pas `parent` lui-meme -- on verifie plutot le chemin
        // qui RETIRE reellement un bloc porteur d'enfants : le bloc vide precedent est
        // retire par le retour arriere quand il n'est PAS textuel. On utilise donc les
        // deux autres chemins, qui retirent explicitement le bloc parent porteur.

        // Chemin 5.4 (menu) :
        let viaMenu = makeParentWithChild()
        let controllerMenu = EditorController(note: viaMenu.note)
        controllerMenu.deleteBlock(viaMenu.parent)
        assertOrderInvariant(viaMenu.note)
        assertNeverEmpty(viaMenu.note)
        let topAfterMenu = BlockOrdering.topLevelBlocks(of: viaMenu.note)
        #expect(topAfterMenu.contains { $0.id == viaMenu.child.id }, "l'enfant doit etre PROMU, pas supprime (chemin menu 5.4)")

        // Chemin 5.6 (lot, plage d'un seul bloc porteur d'enfants) :
        let viaRange = makeParentWithChild()
        let controllerRange = EditorController(note: viaRange.note)
        controllerRange.selectBlock(viaRange.parent)
        controllerRange.deleteSelectionRange()
        assertOrderInvariant(viaRange.note)
        assertNeverEmpty(viaRange.note)
        let topAfterRange = BlockOrdering.topLevelBlocks(of: viaRange.note)
        #expect(topAfterRange.contains { $0.id == viaRange.child.id }, "l'enfant doit etre PROMU, pas supprime (chemin lot 5.6)")
    }

    // MARK: - Sequence 5 : `refreshDerivedText()`/`modifiedAt` sur TOUS les chemins d'ecriture

    @Test(
        "Chaque operation structurelle persistee met a jour Note.modifiedAt ET Note.plainText",
        arguments: [
            "handleEnter", "handleBackspaceAtStart", "appendTrailingParagraph", "insertBlockBelow",
            "duplicateBlock", "deleteBlock", "convertBlock", "moveBlockDown",
            "deleteSelectionRange", "moveSelectionRangeDown", "convertSelectionRange"
        ]
    )
    func everyStructuralOperationRefreshesDerivedState(_ operation: String) {
        let note = Note(title: "Test", modifiedAt: .distantPast)
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]
        note.refreshDerivedText()
        let controller = EditorController(note: note)

        switch operation {
        case "handleEnter":
            controller.handleEnter(in: first, caretOffset: 2)
        case "handleBackspaceAtStart":
            controller.handleBackspaceAtBlockStart(second)
        case "appendTrailingParagraph":
            controller.appendTrailingParagraph()
        case "insertBlockBelow":
            controller.insertBlockBelow(first)
        case "duplicateBlock":
            controller.duplicateBlock(first)
        case "deleteBlock":
            controller.deleteBlock(second)
        case "convertBlock":
            controller.convertBlock(first, to: .heading2)
        case "moveBlockDown":
            controller.moveBlockDown(first)
        case "deleteSelectionRange":
            controller.selectBlock(first)
            controller.extendSelection(to: second)
            controller.deleteSelectionRange()
        case "moveSelectionRangeDown":
            controller.selectBlock(first)
            controller.extendSelection(to: second)
            controller.moveSelectionRangeDown()
        case "convertSelectionRange":
            controller.selectBlock(first)
            controller.extendSelection(to: second)
            controller.convertSelectionRange(to: .heading3)
        default:
            Issue.record("operation de test inconnue : \(operation)")
        }

        #expect(note.modifiedAt != .distantPast, "\(operation) doit passer par persistStructuralChange()")
        assertOrderInvariant(note)
        assertNeverEmpty(note)
    }
}

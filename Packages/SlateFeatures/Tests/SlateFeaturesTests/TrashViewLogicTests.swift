import Testing
@testable import SlateFeatures

/// "Vider la corbeille" reste toujours visible mais desactive quand la corbeille est
/// vide (design P3, artboard B) - jamais masque. Voir `TrashView.isEmptyTrashButtonDisabled(noteCount:)`.
@Suite("TrashView.isEmptyTrashButtonDisabled")
struct TrashViewLogicTests {
    @Test("Corbeille vide : bouton desactive")
    func emptyTrashDisablesButton() {
        #expect(TrashView.isEmptyTrashButtonDisabled(noteCount: 0))
    }

    @Test("Corbeille non vide : bouton actif")
    func nonEmptyTrashEnablesButton() {
        #expect(!TrashView.isEmptyTrashButtonDisabled(noteCount: 1))
        #expect(!TrashView.isEmptyTrashButtonDisabled(noteCount: 4))
    }
}

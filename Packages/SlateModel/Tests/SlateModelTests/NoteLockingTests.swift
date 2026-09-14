import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Verifie l'invariant de securite de la Phase 12, revu en dette de securite fin de
/// jalon v1 (voir la documentation de `Note`, section "Verrouillage") : une note
/// verrouillee n'expose jamais `plainText`/`snippetText` en clair, **et cela reste vrai
/// meme lorsqu'elle est consultee** - `isLocked` est desormais permanent, il n'existe
/// plus de `Note.unlock()` qui le remettrait a `false`.
@MainActor
struct NoteLockingTests {

    private func noteWithContent(title: String = "Confidentiel") -> Note {
        let note = Note(title: title)
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: "Secret."), note: note)]
        note.refreshDerivedText()
        return note
    }

    @Test
    func lockClearsPlainTextAndSnippetButKeepsTitle() {
        let note = noteWithContent()
        #expect(note.plainText == "Secret.")

        note.lock()

        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
        #expect(note.title == "Confidentiel")
    }

    /// Coeur de ce changement : il n'existe plus de `Note.unlock()`. Une note
    /// verrouillee ne peut plus jamais faire repasser `isLocked` a `false`, meme si son
    /// contenu est consulte (voir `computedPlainText` pour l'affichage transitoire de
    /// session, qui ne touche jamais `isLocked`/`plainText`/`snippetText`).
    @Test
    func lockIsPermanentThereIsNoModelLevelUnlock() {
        let note = noteWithContent()

        note.lock()
        #expect(note.isLocked)

        // Un deuxieme appel a lock() (equivalent d'un declencheur de "reverrouillage"
        // qui s'execute sur une note deja verrouillee) est un no-op observable.
        note.lock()
        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
    }

    /// L'invariant est porte par `refreshDerivedText()` lui-meme, pas seulement par
    /// `lock()` : un appel egare (par ex. depuis l'editeur, si jamais il etait
    /// invoque sur une note verrouillee par erreur) ne doit jamais repeupler les
    /// champs derives tant que `isLocked` est vrai - y compris si l'appelant croit la
    /// note "deverrouillee cette session" (un etat qui, par construction, ne vit que
    /// dans `SlateFeatures.AppState`, jamais sur `Note`).
    @Test
    func refreshDerivedTextNeverPopulatesFieldsWhileLocked() {
        let note = Note(title: "Verrouillee", isLocked: true)
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: "Ne doit pas fuiter."), note: note)]

        note.refreshDerivedText()

        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
    }

    /// LE test de ce changement : un deverrouillage suivi d'un `save()` n'ecrit rien en
    /// base. Un contexte frais rechargeant la meme note doit toujours la voir
    /// verrouillee - c'est ce qui rend un arret brutal (plantage, `kill -9`, coupure de
    /// courant) sans consequence sur la confidentialite : il n'y a simplement plus rien
    /// a "reverrouiller" apres coup.
    @Test
    func unlockingIsSessionOnlyAndPersistsNothingToTheStore() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let note = noteWithContent()
        note.lock()
        context.insert(note)
        try context.save()

        // "Deverrouiller" au sens de ce nouveau modele ne consiste plus qu'a lire
        // `note.blocks` directement (voir `NoteDocumentView`) - aucune methode du
        // modele ne fait plus jamais repasser `isLocked` a `false`. On simule ici la
        // consultation en session en lisant `computedPlainText`, qui ne mute rien.
        #expect(note.computedPlainText == "Secret.")
        #expect(note.isLocked)

        try context.save()

        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)

        // Un contexte frais (equivalent d'un relancement de l'app apres arret brutal)
        // voit exactement le meme etat : verrouillee, champs derives vides.
        let freshContext = ModelContext(container)
        let reloaded = try #require(try freshContext.fetch(FetchDescriptor<Note>()).first { $0.id == note.id })
        #expect(reloaded.isLocked)
        #expect(reloaded.plainText.isEmpty)
        #expect(reloaded.snippetText.isEmpty)
    }

    /// `computedPlainText` est le seul chemin d'affichage transitoire d'une note
    /// deverrouillee en session : il reconstruit le texte a la demande, sans jamais
    /// toucher aux champs stockes (qui restent vides tant que `isLocked` est vrai).
    @Test
    func computedPlainTextRebuildsFromBlocksWithoutTouchingStoredFieldsWhileLocked() {
        let note = noteWithContent()
        note.lock()
        #expect(note.plainText.isEmpty)

        #expect(note.computedPlainText == "Secret.")

        // Le calcul transitoire n'a rien ecrit dans les champs stockes.
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
        #expect(note.isLocked)
    }

    /// Cycle complet : verrouiller, consulter (session), verrouiller de nouveau
    /// (fermeture) - le contenu derive reste invariablement vide, la seule chose qui
    /// change etant un etat de session externe a ce type (voir
    /// `AutoRelockCoordinatorTests` pour ce dernier point, hors de portee de `Note`).
    @Test
    func lockConsultRelockCycleLeavesDerivedTextConsistentlyEmpty() {
        let note = noteWithContent()

        note.lock()
        #expect(note.plainText.isEmpty)

        // "Consultation en session" : lecture directe des blocs / du texte transitoire,
        // sans mutation du modele.
        #expect(note.computedPlainText == "Secret.")
        #expect(note.plainText.isEmpty)

        // "Fermeture" (reverrouillage automatique) : plus rien a faire au niveau du
        // modele, `isLocked` n'a jamais bouge.
        note.lock()
        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
    }

    /// La suppression en cascade d'une note verrouillee doit rester identique a celle
    /// d'une note ordinaire (non-regression : le verrouillage ne doit pas interferer
    /// avec le cycle de vie SwiftData de la note ou de ses blocs).
    @Test
    func lockedNoteStillCascadeDeletesItsBlocks() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let note = noteWithContent()
        note.lock()
        let block = note.blocks?.first
        context.insert(note)
        try context.save()

        context.delete(note)
        try context.save()

        let remainingBlocks = try context.fetch(FetchDescriptor<Block>())
        #expect(!remainingBlocks.contains { $0.id == block?.id })
    }
}

import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Verifie le critere d'acceptation de la Phase 1 : "une entite placeholder persiste
/// entre deux lancements" (docs/01_setup_projet.md). A la difference de
/// `PersistenceTests`, qui utilise `isStoredInMemoryOnly: true` (rien ne prouve la
/// persistance disque), ce test ouvre un vrai store sur un fichier, le referme
/// completement, puis en rouvre un second sur la meme URL pour simuler deux
/// lancements successifs de l'app.
@MainActor
struct DiskPersistenceTests {

    @Test
    func noteWrittenInFirstLaunchIsReadableInSecondLaunch() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appending(path: "Slate.store")

        // --- Premier "lancement" : ecrit une note et referme tout. ---
        try {
            let container = try SlateContainer.make(storeURL: storeURL)
            let context = ModelContext(container)
            context.insert(Note(title: "Note du premier lancement"))
            try context.save()
        }()
        // A la sortie de cette portee, `container` et `context` ne sont plus references :
        // le second "lancement" ci-dessous doit repartir uniquement du fichier sur disque.

        // --- Second "lancement" : nouveau container sur la meme URL. ---
        let reopenedContainer = try SlateContainer.make(storeURL: storeURL)
        let reopenedContext = ModelContext(reopenedContainer)

        let fetched = try reopenedContext.fetch(FetchDescriptor<Note>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "Note du premier lancement")
    }
}

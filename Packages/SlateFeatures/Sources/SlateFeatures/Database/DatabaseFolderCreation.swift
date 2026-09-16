import Foundation
import SlateModel

/// Creation d'une base PLEINE PAGE dans un dossier (Phase 17, "les deux hebergements" :
/// `Database.hostMode == .fullPage`, rattachee via `Folder.databases`). Logique PURE
/// (aucun `ModelContext`) extraite de `NoteListView.createDatabase(in:)` pour rester
/// testable sans construire de vue SwiftUI -- meme motif que `FolderDeletionCleanup`.
///
/// N'insere JAMAIS le resultat dans un `ModelContext` : comme le reste du modele (voir
/// `EntityGraphTests`, `SlateModel`), c'est a l'appelant d'inserer les objets
/// nouvellement crees (`database` et son premier champ).
enum DatabaseFolderCreation {
    /// Une base fraichement creee, prete a etre inseree dans un `ModelContext` par
    /// l'appelant (voir la documentation de tete).
    struct NewDatabase {
        let database: Database
        let firstField: DatabaseField
    }

    /// Cree une base pleine page dans `folder`, avec un premier champ Texte par defaut
    /// deja rattache -- jamais une grille sans aucune colonne (meme raisonnement que
    /// `EditorController.executeDatabaseCommand(in:)` de `SlateEditor` pour la base
    /// inline). Rattache aussi la nouvelle base a `folder.databases`.
    static func makeDatabase(
        in folder: Folder,
        name: String,
        firstFieldName: String
    ) -> NewDatabase {
        let database = Database(name: name, hostMode: .fullPage, folder: folder)
        let firstField = DatabaseField(name: firstFieldName, order: 0, fieldType: .text, database: database)
        database.fields = [firstField]
        folder.databases?.append(database)
        return NewDatabase(database: database, firstField: firstField)
    }
}

import Foundation
import SlateModel

/// Cas particulier `databaseView` de l'execution du menu "/" (Phase 17,
/// `docs/17_base_de_donnees.md`) -- extrait de `EditorController+SlashMenu.swift` pour
/// rester sous la limite de longueur de fichier de `CLAUDE.md` §5, meme motif de
/// separation que `EditorController+SlashMenu+Media.swift`. Un seul type
/// (`EditorController`), aucune nouvelle surface publique qui lui soit propre.
extension EditorController {
    /// Meme motif exact que `executeMediaCommand(targetType:in:)` (voir sa
    /// documentation) -- `databaseView` ne porte pas de `RichText` propre ni ne peut
    /// accueillir le caret, donc TOUJOURS un nouveau bloc insere en dessous de `block`,
    /// suivi d'un paragraphe vide qui recoit le focus. La difference : ce nouveau bloc
    /// heberge IMMEDIATEMENT une `Database` inline fraichement creee (`hostMode: .inline`,
    /// `hostBlock`), avec un premier champ Texte par defaut ("Nom") -- une base inline
    /// vide sans aucun champ serait une grille sans colonne, donc sans rien a afficher ni
    /// a ajouter : le premier champ garantit que la grille est immediatement utilisable,
    /// exactement l'exigence d'honnetete d'interface du projet (jamais un composant qui a
    /// l'air pret sans rien pouvoir faire).
    func executeDatabaseCommand(in block: Block) {
        let databaseBlock = Block(type: .databaseView)
        BlockOrdering.insert(databaseBlock, after: block)

        let database = Database(name: "", hostMode: .inline, hostBlock: databaseBlock)
        let nameField = DatabaseField(
            name: String(localized: "editor.databaseView.defaultField.name", bundle: .module),
            order: 0,
            fieldType: .text,
            database: database
        )
        database.fields = [nameField]
        databaseBlock.databaseView = database
        modelContext?.insert(database)
        modelContext?.insert(nameField)

        let trailingParagraph = Block(type: .paragraph, text: RichText())
        BlockOrdering.insert(trailingParagraph, after: databaseBlock)
        applyFocus(EditorCaretRequest(blockID: trailingParagraph.id, placement: .offset(0)))
    }
}

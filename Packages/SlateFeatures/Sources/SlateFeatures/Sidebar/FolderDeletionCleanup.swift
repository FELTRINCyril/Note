import SlateModel

/// Calcule quelles references de selection doivent etre effacees avant de supprimer un
/// dossier (revue de fin de Phase 3 : `AppState` porte desormais des references
/// directes vers des objets `@Model`, voir la documentation d'`AppState`). Les regles
/// de suppression en cascade posees sur `Folder.subfolders`/`Folder.notes`
/// (`docs/GLOSSAIRE.md`, `Folder.swift`) signifient que supprimer un dossier supprime
/// aussi, recursivement, tous ses sous-dossiers et toutes leurs notes : une reference
/// tenue par `AppState`/l'etat de focus clavier sur n'importe lequel de ces objets
/// devient pendante si elle n'est pas nettoyee au meme moment.
///
/// Fonction pure (aucun `ModelContext`, aucune mutation, aucune lecture d'un objet deja
/// supprime) : elle prend un instantane de l'etat de selection AVANT toute suppression
/// et renvoie un plan que l'appelant applique lui-meme, egalement avant d'appeler
/// `SidebarNavigation.delete(_:)`. Lire une propriete d'un objet SwiftData deja
/// supprime n'est pas un comportement garanti ; ce type existe precisement pour que
/// personne n'ait a le faire.
public enum FolderDeletionCleanup {
    /// Ce qu'il faut effacer avant de supprimer un dossier.
    public struct Plan: Equatable, Sendable {
        /// `AppState.selectedFolder` doit etre remis a `nil`.
        public let clearsSelectedFolder: Bool
        /// `AppState.selectedNote` doit etre remise a `nil`.
        public let clearsSelectedNote: Bool
        /// L'etat de focus clavier (`focusedFolderID`) doit etre remis a `nil`.
        public let clearsFocusedFolder: Bool

        public init(clearsSelectedFolder: Bool, clearsSelectedNote: Bool, clearsFocusedFolder: Bool) {
            self.clearsSelectedFolder = clearsSelectedFolder
            self.clearsSelectedNote = clearsSelectedNote
            self.clearsFocusedFolder = clearsFocusedFolder
        }

        /// Aucune reference n'est affectee par la suppression.
        public static let none = Plan(
            clearsSelectedFolder: false, clearsSelectedNote: false, clearsFocusedFolder: false
        )
    }

    /// Calcule le plan de nettoyage pour la suppression de `deletedFolder`.
    ///
    /// - `selectedFolder` est efface si c'est `deletedFolder` lui-meme, OU un de ses
    ///   descendants a n'importe quelle profondeur (pas seulement un enfant direct).
    ///   Un frere de `deletedFolder`, ou un de ses ancetres, n'est jamais efface :
    ///   supprimer un sous-dossier ne doit pas faire perdre la selection du dossier
    ///   parent qui reste, lui, parfaitement valide.
    /// - `selectedNote` est effacee dans les memes conditions que `selectedFolder`
    ///   (voir note ci-dessous), et aussi si elle appartient elle-meme, directement, a
    ///   un dossier efface par cette regle (`selectedNote.folder`).
    /// - `focusedFolder` (etat de focus clavier ephemere) suit exactement la meme regle
    ///   que `selectedFolder`.
    ///
    /// ## Pourquoi `selectedNote` suit `selectedFolder`
    ///
    /// Dans l'UI actuelle (`SidebarView`/Phase 3-4), une note selectionnee n'a de sens
    /// que rattachee au dossier actuellement affiche dans la colonne du milieu
    /// (`AppState.selectedFolder`) : c'est la liste de CE dossier qui la contient et la
    /// rend selectionnable. Si ce dossier disparait (lui-meme ou un de ses
    /// descendants), la colonne du milieu qui affichait la note n'a plus de sens, donc
    /// la selection de note doit disparaitre avec elle - meme si, par construction du
    /// modele, `selectedNote.folder` designerait deja le meme dossier. Le second test
    /// (appartenance directe de `selectedNote.folder`) est redondant avec le premier
    /// dans l'usage actuel, mais rend la fonction correcte aussi si `AppState` en vient
    /// a decoupler un jour selection de note et selection de dossier.
    ///
    /// ## Pourquoi remonter la chaine des parents plutot que descendre l'arbre
    ///
    /// Verifier l'appartenance en remontant `Folder.parent` depuis la selection est en
    /// O(profondeur de la selection dans l'arbre), independant de la taille du
    /// sous-arbre supprime, et ne peut pas "manquer" un descendant par une erreur de
    /// parcours descendant (ex : filtrage incomplet des sous-dossiers).
    public static func plan(
        deleting deletedFolder: Folder,
        selectedFolder: Folder?,
        selectedNote: Note?,
        focusedFolder: Folder?
    ) -> Plan {
        let selectedFolderIsAffected = selectedFolder.map {
            isFolder($0, sameAsOrDescendantOf: deletedFolder)
        } ?? false

        let selectedNoteFolderIsAffected = selectedNote?.folder.map {
            isFolder($0, sameAsOrDescendantOf: deletedFolder)
        } ?? false

        let focusedFolderIsAffected = focusedFolder.map {
            isFolder($0, sameAsOrDescendantOf: deletedFolder)
        } ?? false

        return Plan(
            clearsSelectedFolder: selectedFolderIsAffected,
            clearsSelectedNote: selectedFolderIsAffected || selectedNoteFolderIsAffected,
            clearsFocusedFolder: focusedFolderIsAffected
        )
    }

    /// `true` si `folder` est `ancestor` lui-meme, ou un descendant de `ancestor` a
    /// n'importe quelle profondeur, determine en remontant la chaine `Folder.parent`
    /// depuis `folder`.
    public static func isFolder(_ folder: Folder, sameAsOrDescendantOf ancestor: Folder) -> Bool {
        var current: Folder? = folder
        while let node = current {
            if node.id == ancestor.id {
                return true
            }
            current = node.parent
        }
        return false
    }
}

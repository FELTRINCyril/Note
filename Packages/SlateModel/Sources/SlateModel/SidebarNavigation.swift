import Foundation
import SwiftData

/// Couche de requetes et de mutations pour l'arborescence affichee dans la sidebar
/// (`docs/03_sidebar_navigation.md`), independante de toute vue SwiftUI : c'est
/// exactement le peu de logique dont `SidebarView` (Phase 3, `SlateFeatures`) a besoin,
/// mais entierement testable depuis `SlateModelTests` sans jamais construire d'UI.
///
/// ## Forme retenue : un type au lieu de methodes eparpillees sur les entites
///
/// Les requetes de simple traversee de relation deja chargee (`spaces(in:)`,
/// `rootFolders(in:)`, `subfolders(of:)`) auraient pu etre des methodes sur
/// `Workspace`/`Space`/`Folder` directement, comme `Folder.noteCount` dans
/// `SidebarOrdering.swift`. Mais les mutations (creer/renommer/supprimer un dossier,
/// creer une note, reordonner des freres) ont toutes besoin d'un `ModelContext` pour
/// inserer/supprimer/sauvegarder - or `ModelContext` n'est pas `Sendable`, donc les
/// deux camps de methodes (lecture pure vs mutation) doivent de toute facon vivre dans
/// un contexte isole a un seul acteur. Plutot que de disperser des fonctions libres
/// `func createFolder(in context: ModelContext, ...)`, ce type regroupe requetes ET
/// mutations dans une seule petite API decouverte facilement par un appelant
/// SwiftUI : `SidebarNavigation(context: modelContext).createFolder(...)`.
///
/// ## Isolation
///
/// Le type est marque `@MainActor` : c'est la ou vivent les vues SwiftUI qui
/// l'utiliseront (Phase 3), et c'est la ou vit `ModelContext.mainContext`/le contexte
/// injecte par `.modelContainer(_:)`. Aucune tentative n'est faite de le rendre
/// utilisable depuis un contexte concurrent : ce n'est pas le besoin de la sidebar, et
/// SwiftData recommande un `ModelActor` dedie (hors du perimetre de cette tache) pour
/// tout travail de fond sur le modele.
@MainActor
public struct SidebarNavigation {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Requetes

    /// Sections de premier niveau d'un workspace, triees de facon deterministe
    /// (voir `Space.sidebarOrder`).
    public func spaces(in workspace: Workspace) -> [Space] {
        (workspace.spaces ?? []).sorted(by: Space.sidebarOrder)
    }

    /// Dossiers racine (sans parent) d'une section, tries de facon deterministe (voir
    /// `Folder.sidebarOrder`).
    public func rootFolders(in space: Space) -> [Folder] {
        (space.folders ?? []).filter { $0.parent == nil }.sorted(by: Folder.sidebarOrder)
    }

    /// Sous-dossiers directs d'un dossier, tries de facon deterministe (voir
    /// `Folder.sidebarOrder`).
    public func subfolders(of folder: Folder) -> [Folder] {
        (folder.subfolders ?? []).sorted(by: Folder.sidebarOrder)
    }

    /// Notes favorites (`isFavorite`) d'un workspace, en excluant la corbeille
    /// (`isTrashed`), pour la section Favoris de la sidebar. Triees par titre (ordre
    /// naturel), puis par `id` pour rester deterministe en cas de titres identiques.
    ///
    /// Implementee par un vrai `FetchDescriptor` (pas par une traversee de relations
    /// en memoire) car "toutes les notes favorites d'un workspace" n'est pas une
    /// relation directe du modele : elle traverse `Note -> folder -> space ->
    /// workspace`.
    public func favoriteNotes(in workspace: Workspace) throws -> [Note] {
        let predicate = #Predicate<Note> { note in
            note.isFavorite && !note.isTrashed
        }
        let descriptor = FetchDescriptor<Note>(predicate: predicate)
        let candidates = try context.fetch(descriptor)

        return candidates
            .filter { $0.folder?.space?.workspace?.id == workspace.id }
            .sorted { lhs, rhs in
                let titleComparison = lhs.title.localizedStandardCompare(rhs.title)
                if titleComparison != .orderedSame {
                    return titleComparison == .orderedAscending
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    // MARK: - Mutations

    /// Cree un dossier dans une section, optionnellement comme sous-dossier d'un
    /// dossier existant. Si `parent` est fourni, la section effective est celle du
    /// parent (`parent.space`) plutot que le parametre `space`, pour ne jamais
    /// pouvoir creer un sous-dossier dont la section ne correspond pas a celle de son
    /// parent - `space` reste neanmoins un parametre a part entiere (et pas deduit
    /// implicitement) pour l'appel le plus courant, la creation d'un dossier racine.
    ///
    /// Le nouveau dossier est place en derniere position parmi ses freres
    /// (`sortIndex` = nombre de freres existants).
    @discardableResult
    public func createFolder(named name: String, in space: Space, parent: Folder? = nil) throws -> Folder {
        let effectiveSpace = parent?.space ?? space
        let siblingCount = parent.map { ($0.subfolders ?? []).count }
            ?? (space.folders ?? []).count { $0.parent == nil }

        let folder = Folder(name: name, sortIndex: siblingCount, space: effectiveSpace, parent: parent)
        context.insert(folder)
        try context.save()
        return folder
    }

    /// Renomme un dossier existant.
    public func rename(_ folder: Folder, to newName: String) throws {
        folder.name = newName
        try context.save()
    }

    /// Supprime un dossier. Les sous-dossiers, notes, blocs et pieces jointes qu'il
    /// contient sont supprimes en cascade (regles de suppression posees en Phase 2 sur
    /// `Folder.subfolders`/`Folder.notes`) ; la section parente et le workspace ne
    /// sont jamais affectes.
    public func delete(_ folder: Folder) throws {
        context.delete(folder)
        try context.save()
    }

    /// Cree une note vide dans un dossier.
    ///
    /// Appelle explicitement `refreshDerivedText()` : la nouvelle note n'a aucun bloc,
    /// donc `plainText`/`snippetText` restent a `""` (deja la valeur par defaut de
    /// `Note.init`), mais l'appel est fait ici quand meme par discipline plutot que
    /// de compter sur la valeur par defaut - voir la documentation de `Note` sur le
    /// risque de desynchronisation de ces deux champs. **Si cette methode se met un
    /// jour a amorcer un premier bloc de contenu (un paragraphe vide, par exemple),
    /// cet appel devient strictement necessaire** et ne doit pas etre retire.
    @discardableResult
    public func createNote(titled title: String, in folder: Folder) throws -> Note {
        let note = Note(title: title, folder: folder)
        note.refreshDerivedText()
        context.insert(note)
        try context.save()
        return note
    }

    /// Assigne (ou retire, avec `nil`) la couleur personnalisee d'un dossier. Voir
    /// `Folder.colorToken` pour la semantique complete (`nil` = repli sur le hachage
    /// de l'`id` cote UI).
    public func setColor(_ colorToken: FolderColorToken?, for folder: Folder) throws {
        folder.colorToken = colorToken
        try context.save()
    }

    /// Reordonne des dossiers freres : `orderedFolders` doit contenir exactement
    /// l'ensemble des freres (meme parent, ou meme section pour des dossiers racine)
    /// dans le nouvel ordre voulu. Chaque dossier recoit un `sortIndex` egal a sa
    /// position dans ce tableau (0, 1, 2...).
    ///
    /// Ne valide pas que les dossiers passes partagent effectivement le meme
    /// parent/section : c'est a l'appelant (le futur glisser-deposer de la sidebar,
    /// cf. `docs/03_sidebar_navigation.md`, reporte pour l'instant) de ne fournir que
    /// des freres reels. Cote modele, l'operation elle-meme - "assigner des
    /// `sortIndex` consecutifs selon un ordre donne" - est correcte quel que soit
    /// l'appelant.
    public func reorderSiblings(_ orderedFolders: [Folder]) throws {
        for (index, folder) in orderedFolders.enumerated() {
            folder.sortIndex = index
        }
        try context.save()
    }
}

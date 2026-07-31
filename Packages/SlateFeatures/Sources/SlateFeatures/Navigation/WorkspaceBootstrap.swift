import Foundation
import SwiftData
import SlateModel

/// Amorce un `Workspace` par defaut au tout premier lancement.
///
/// `docs/GLOSSAIRE.md` §1 : le multi-workspace n'est reellement exploite qu'en
/// Phase 19 ; jusque-la, l'app doit neanmoins presenter un workspace (et une section
/// "Espaces" fonctionnelle) sans qu'aucune phase precedente n'ait cree cette donnee de
/// depart. `SlateModel` n'expose aucune methode `createWorkspace`/`createSpace` (le
/// contrat de `SidebarNavigation` ne couvre que dossiers/notes) : ce type insere
/// directement les entites via l'API publique deja exposee par `Workspace`/`Space`
/// (proprietes `public var`, `init` public), sans modifier `SlateModel`.
@MainActor
public enum WorkspaceBootstrap {
    /// Garantit qu'au moins un `Workspace` existe, avec au moins une `Space`.
    ///
    /// - Ne fait rien si un workspace existe deja (idempotent : sur.rce de verite,
    ///   pas d'appel a effectuer explicitement plus d'une fois par lancement).
    /// - Retourne le workspace a utiliser (le premier existant, trie par
    ///   `sortIndex`/nom pour rester deterministe, ou celui qui vient d'etre cree).
    @discardableResult
    public static func ensureDefaultWorkspace(in context: ModelContext) throws -> Workspace {
        let descriptor = FetchDescriptor<Workspace>(
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.name)]
        )
        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let workspace = Workspace(
            name: String(localized: "workspace.default.name", bundle: .module)
        )
        let space = Space(
            name: String(localized: "space.default.name", bundle: .module),
            workspace: workspace
        )
        workspace.spaces = [space]
        context.insert(workspace)
        context.insert(space)
        try context.save()
        return workspace
    }
}

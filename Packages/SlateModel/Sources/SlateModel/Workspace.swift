import Foundation
import SwiftData

/// Cloisonnement de plus haut niveau, totalement isole (ex. "Pro", "Perso").
///
/// Voir `docs/GLOSSAIRE.md` §1 : pose en Phase 2, reellement exploite en Phase 19
/// (multi-workspace). Un seul workspace suffit pour le fonctionnement courant de
/// l'app tant que la Phase 19 n'est pas faite.
///
/// Contraintes CloudKit (voir `docs/DEV_ENV.md`) : toutes les proprietes ont une
/// valeur par defaut, la relation `spaces` est optionnelle avec une valeur par
/// defaut `[]`.
@Model
public final class Workspace {
    public var id: UUID = UUID()
    public var name: String = ""
    public var iconName: String = "square.stack"
    public var accentColorHex: String = "#0A84FF"
    public var createdAt: Date = Date.now
    public var sortIndex: Int = 0

    /// Sections de haut niveau contenues dans ce workspace. Supprimer un workspace
    /// supprime toutes ses sections (et, par cascade, tout ce qu'elles contiennent).
    @Relationship(deleteRule: .cascade, inverse: \Space.workspace)
    public var spaces: [Space]? = []

    public init(
        id: UUID = UUID(),
        name: String = "",
        iconName: String = "square.stack",
        accentColorHex: String = "#0A84FF",
        createdAt: Date = .now,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.accentColorHex = accentColorHex
        self.createdAt = createdAt
        self.sortIndex = sortIndex
    }
}

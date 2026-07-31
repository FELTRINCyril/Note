import Foundation
import SwiftData

/// Regroupement de haut niveau a l'interieur d'un `Workspace`, equivalent d'un compte
/// ou d'une grande rubrique dans la sidebar (comme "iCloud" / "Sur mon Mac" dans Notes
/// d'Apple). Voir `docs/GLOSSAIRE.md` §1.
///
/// Contraintes CloudKit : toutes les proprietes ont une valeur par defaut ; `workspace`
/// est optionnel (l'inverse est declare du cote `Workspace.spaces`) ; `folders` est
/// optionnel avec une valeur par defaut `[]`.
@Model
public final class Space {
    public var id: UUID = UUID()
    public var name: String = ""
    public var iconName: String = "folder"
    public var sortIndex: Int = 0

    /// Workspace parent. L'inverse de cette relation est declare une seule fois, du
    /// cote `Workspace.spaces` (`@Relationship(inverse:)`).
    public var workspace: Workspace?

    /// Dossiers de premier niveau contenus dans cette section. Supprimer une section
    /// supprime tous ses dossiers (et, par cascade, tout ce qu'ils contiennent).
    @Relationship(deleteRule: .cascade, inverse: \Folder.space)
    public var folders: [Folder]? = []

    public init(
        id: UUID = UUID(),
        name: String = "",
        iconName: String = "folder",
        sortIndex: Int = 0,
        workspace: Workspace? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.sortIndex = sortIndex
        self.workspace = workspace
    }
}

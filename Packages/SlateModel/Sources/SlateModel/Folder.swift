import Foundation
import SwiftData

/// Conteneur recursif : un dossier peut contenir des sous-dossiers et des notes.
/// Appartient a une `Space`. Voir `docs/GLOSSAIRE.md` §1.
///
/// Contraintes CloudKit : toutes les proprietes ont une valeur par defaut ; `space` et
/// `parent` sont optionnels ; `subfolders` et `notes` sont optionnels avec une valeur
/// par defaut `[]`.
///
/// La relation `parent`/`subfolders` est auto-referencee (un `Folder` pointe vers un
/// autre `Folder`) : l'inverse est declare une seule fois, sur `subfolders`, en pointant
/// vers `\Folder.parent` du meme type.
@Model
public final class Folder {
    public var id: UUID = UUID()
    public var name: String = ""
    public var iconName: String = "folder"
    public var sortIndex: Int = 0
    public var createdAt: Date = Date.now

    /// Section parente. L'inverse est declare du cote `Space.folders`.
    public var space: Space?

    /// Dossier parent, `nil` si ce dossier est a la racine de sa `Space`.
    public var parent: Folder?

    /// Sous-dossiers directs. Supprimer ce dossier supprime recursivement tous ses
    /// sous-dossiers (et, par cascade, tout ce qu'ils contiennent).
    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    public var subfolders: [Folder]? = []

    /// Notes contenues directement dans ce dossier (pas dans ses sous-dossiers).
    /// Supprimer ce dossier supprime ces notes (et, par cascade, leurs blocs et
    /// pieces jointes).
    @Relationship(deleteRule: .cascade, inverse: \Note.folder)
    public var notes: [Note]? = []

    public init(
        id: UUID = UUID(),
        name: String = "",
        iconName: String = "folder",
        sortIndex: Int = 0,
        createdAt: Date = .now,
        space: Space? = nil,
        parent: Folder? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.space = space
        self.parent = parent
    }
}

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

    /// Etat plie/deplie de ce dossier dans l'arbre de la sidebar (Phase 3, voir
    /// `docs/03_sidebar_navigation.md`). Persiste d'un lancement a l'autre puisque
    /// c'est une propriete stockee du modele, pas un etat de vue ephemere.
    ///
    /// Valeur par defaut retenue : `true` (deplie). Justification : un dossier qui
    /// vient d'etre cree n'a pas encore de sous-dossiers, donc l'etat plie/deplie n'a
    /// aucun effet visible tant qu'on ne lui ajoute pas d'enfants ; le jour ou on lui
    /// en ajoute, les demarrer visibles (deplie) est plus decouvrable pour
    /// l'utilisateur qu'un sous-dossier cache par defaut qu'il faudrait penser a
    /// deplier soi-meme. C'est aussi la valeur par defaut la plus sure pour la
    /// migration additive de cette propriete (voir `SlateSchema.swift`) : tout dossier
    /// deja present sur disque avant l'ajout de ce champ redevient "deplie" plutot que
    /// silencieusement "plie", ce qui evite de donner l'impression a l'utilisateur que
    /// des dossiers existants ont disparu.
    public var isExpanded: Bool = true

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
        isExpanded: Bool = true,
        space: Space? = nil,
        parent: Folder? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.isExpanded = isExpanded
        self.space = space
        self.parent = parent
    }
}

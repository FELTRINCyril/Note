import Foundation
import SwiftData

/// Conteneur recursif : un dossier peut contenir des sous-dossiers et des notes.
/// Appartient a une `Space`. Voir `docs/GLOSSAIRE.md` §1.
///
/// Contraintes CloudKit : toutes les proprietes ont une valeur par defaut ou sont
/// optionnelles (`colorIndex` est optionnel, voir sa documentation) ; `space` et
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

    /// Index de couleur choisi explicitement par l'utilisateur dans la palette de
    /// `design/tokens.md` §7/§8 (8 entrees, `FolderColorToken`), ou `nil` si
    /// l'utilisateur n'a jamais defini de couleur pour ce dossier.
    ///
    /// **`nil` est une valeur a part entiere, pas une absence a corriger** : c'est le
    /// signal explicite que l'UI doit se replier sur le hachage deterministe de
    /// `Folder.id` deja implemente cote `SlateUI` (chaque dossier sans choix explicite
    /// garde neanmoins une couleur stable et distincte). Ne jamais faire de ce champ
    /// une propriete non optionnelle avec une couleur par defaut : cela detruirait la
    /// distinction entre "l'utilisateur a choisi le bleu" et "l'utilisateur n'a rien
    /// choisi".
    ///
    /// Stocke comme `Int?` brut (pas directement `FolderColorToken?`) parce que
    /// SwiftData persiste les enums `Codable`/`RawRepresentable` via leur `rawValue`
    /// de toute facon, et qu'un `Int?` simple documente sans ambiguite la contrainte
    /// CloudKit (propriete optionnelle, type scalaire). Voir `colorToken` pour l'API
    /// typee, et sa documentation pour le traitement d'un index hors bornes.
    public var colorIndex: Int?

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

    /// Bases de donnees pleine page contenues directement dans ce dossier (Phase 17,
    /// voir `Database.hostMode`). Supprimer ce dossier supprime ces bases (et, par
    /// cascade, leurs champs, lignes et cellules).
    @Relationship(deleteRule: .cascade, inverse: \Database.folder)
    public var databases: [Database]? = []

    public init(
        id: UUID = UUID(),
        name: String = "",
        iconName: String = "folder",
        sortIndex: Int = 0,
        createdAt: Date = .now,
        isExpanded: Bool = true,
        colorIndex: Int? = nil,
        space: Space? = nil,
        parent: Folder? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.isExpanded = isExpanded
        self.colorIndex = colorIndex
        self.space = space
        self.parent = parent
    }

    /// API typee pour lire/ecrire la couleur explicite de ce dossier.
    ///
    /// - Lecture : `nil` si `colorIndex` est `nil` (aucun choix utilisateur) **ou** si
    ///   `colorIndex` porte une valeur hors des bornes actuelles de la palette (0...7).
    ///   Ce deuxieme cas n'arrive pas en usage normal (rien dans l'API publique ne
    ///   permet d'ecrire un index invalide), mais peut survenir si la palette venait a
    ///   retrecir dans une version future, ou par prudence face a des donnees ecrites
    ///   par une version future de l'app puis relues par une version plus ancienne (un
    ///   scenario reel avec la synchronisation CloudKit). Dans ce cas, retomber sur
    ///   `nil` est le choix sur : cela declenche exactement le meme repli sur le
    ///   hachage de `id` que "aucune couleur choisie", plutot qu'un crash ou une
    ///   couleur arbitraire.
    /// - Ecriture : `nil` efface le choix explicite (retour au hachage de `id`) ; toute
    ///   autre valeur ecrit son `rawValue`, necessairement dans les bornes puisque
    ///   `FolderColorToken` est un enum ferme.
    public var colorToken: FolderColorToken? {
        get { colorIndex.flatMap(FolderColorToken.init(rawValue:)) }
        set { colorIndex = newValue?.rawValue }
    }
}

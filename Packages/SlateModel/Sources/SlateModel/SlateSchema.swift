import Foundation
import SwiftData

/// Version 1 du schema SwiftData de Slate : les 7 entites du modele conceptuel
/// (`docs/02_modele_donnees.md`) - `Workspace`, `Space`, `Folder`, `Note`, `Block`,
/// `Attachment`, `Tag`.
///
/// Cette version n'a encore aucune migration a decrire : elle est la premiere. La
/// structure `VersionedSchema` est mise en place des maintenant (plutot qu'ajoutee au
/// moment de la premiere vraie migration) parce que SwiftData/CloudKit exigent qu'un
/// `ModelContainer` deja livre a des utilisateurs migre a partir d'un schema
/// explicitement versionne : retrofitter un versionnement une fois des donnees reelles
/// en circulation est plus risque que le poser vide dès le depart.
///
/// ## Phase 3 : ajout de `Folder.isExpanded` sans bump de version
///
/// La Phase 3 (`docs/03_sidebar_navigation.md`) a ajoute `Folder.isExpanded: Bool =
/// true`, alors qu'un store existait deja sur disque avec la forme precedente de
/// `Folder` (sans ce champ). Decision : **rester en `versionIdentifier(1, 0, 0)`, ne
/// pas creer de `SlateSchemaV2`.**
///
/// Raisons :
/// - Le changement est **purement additif** : une propriete `Bool` supplementaire
///   avec une valeur par defaut, sur une entite existante. Aucun renommage, aucune
///   suppression, aucun changement de type. C'est exactement la categorie de
///   changement que SwiftData/Core Data migrent seuls, de facon automatique
///   ("lightweight migration" inferee), sans qu'une etape de `MigrationStage` explicite
///   soit necessaire : au premier chargement d'un store existant, la colonne
///   manquante est ajoutee et remplie avec sa valeur par defaut pour chaque ligne deja
///   presente.
/// - Slate synchronise via **CloudKit** (voir `docs/01_setup_projet.md`), et CloudKit
///   n'autorise de toute facon QUE des evolutions additives d'un schema mirrore (pas
///   de renommage, pas de suppression, pas de changement de type, jamais). Un vrai
///   `MigrationStage.custom` n'est donc pas quelque chose que ce schema pourra un jour
///   exploiter une fois la synchronisation active : la seule categorie de migration
///   que Slate connaitra jamais est celle-ci, l'additive, et elle n'exige pas de
///   bump de version pour fonctionner.
/// - Dupliquer `SlateSchemaV1` en `SlateSchemaV2` aurait, par construction de
///   `VersionedSchema`, oblige a dupliquer aussi `Workspace`, `Space` et `Note` (tout
///   le sous-graphe relie a `Folder` par une relation typee) dans un espace de noms
///   `SlateSchemaV1` gele, pour un gain de securite nul face a un changement qui reste
///   dans le cas "additif" gere nativement. Voir la preuve empirique dans
///   `FolderExpandedStateMigrationTests` (`Tests/SlateModelTests`), qui ouvre un store
///   construit avec l'ancienne forme de `Folder` (sans `isExpanded`) via le vrai
///   `SlateContainer` de production et verifie que les donnees existantes survivent et
///   que `isExpanded` prend bien sa valeur par defaut.
///
/// Si une future evolution de `Folder` (ou de toute autre entite) devait un jour
/// renommer un champ, changer son type ou en supprimer un, la question redeviendrait
/// legitime : ce jour-la, `SlateSchemaV2` devra exister avec ses propres types geles
/// pour tout le sous-graphe concerne, et une vraie etape de `MigrationStage` (probable
/// `.custom`, hors du perimetre CloudKit puisqu'un renommage casse la synchronisation -
/// a signaler explicitement a Cyril avant de s'y engager).
/// ## Phase 17 : ajout de 4 entites (`Database`, `DatabaseField`, `DatabaseRow`,
/// `DatabaseCell`) sans bump de version
///
/// Meme raisonnement que pour `Folder.isExpanded` ci-dessus, applique cette fois a
/// l'ajout d'entites entieres plutot que de proprietes : ajouter de nouveaux types de
/// modele (donc de nouvelles tables/nouveaux record types CloudKit) a un schema existant
/// est une operation additive, geree nativement par la migration legere de Core Data et
/// autorisee par CloudKit. Aucun type existant n'est modifie (Block/Folder gagnent une
/// relation optionnelle supplementaire, elle-meme additive au meme titre). Rester en
/// `versionIdentifier(1, 0, 0)` reste donc coherent avec la regle deja posee : seul un
/// renommage/une suppression/un changement de type justifierait une `SlateSchemaV2`.
public enum SlateSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            Workspace.self,
            Space.self,
            Folder.self,
            Note.self,
            Block.self,
            Attachment.self,
            Tag.self,
            Database.self,
            DatabaseField.self,
            DatabaseRow.self,
            DatabaseCell.self
        ]
    }
}

/// Plan de migration de Slate. Une seule version enregistree pour l'instant : aucune
/// etape de migration (`stages`) n'est necessaire tant qu'une V2 n'existe pas. Quand
/// une V2 sera introduite, un `MigrationStage` (`.lightweight` ou `.custom`) viendra
/// s'ajouter ici, jamais en modifiant `SlateSchemaV1` retroactivement.
public enum SlateSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SlateSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}

/// Point unique d'enregistrement du schema SwiftData de Slate, expose comme API
/// simple pour `ModelContainerFactory`/`SlateContainer` (ne change pas quand une
/// nouvelle version de schema est ajoutee : seul `SlateSchema.current` change de
/// cible).
public enum SlateSchema {
    /// Version de schema courante utilisee par l'app.
    public typealias Current = SlateSchemaV1

    /// Numero de version courant, pour affichage de diagnostic. Correspond a
    /// `SlateSchemaV1.versionIdentifier.major`.
    public static let version = 1

    /// Liste des types `@Model` composant le schema courant, dans l'ordre attendu par
    /// `ModelContainer`/`Schema`.
    public static var models: [any PersistentModel.Type] {
        Current.models
    }
}

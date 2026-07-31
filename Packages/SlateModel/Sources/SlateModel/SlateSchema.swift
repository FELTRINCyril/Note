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
            Tag.self
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

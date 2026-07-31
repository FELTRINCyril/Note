import Foundation
import SwiftData

/// Point unique d'enregistrement du schema SwiftData de Slate.
///
/// Phase 1 : contient uniquement le modele placeholder `Note`. Le vrai schema
/// (Workspace, Space, Folder, Note, Block, Attachment, Tag) sera enregistre ici
/// en Phase 2 (docs/02_modele_donnees.md), avec un `VersionedSchema` et un
/// `SchemaMigrationPlan` si une migration est necessaire a ce moment-la.
public enum SlateSchema {
    /// Version du schema courant, a incrementer a chaque evolution structurante.
    public static let version = 1

    /// Liste des types `@Model` composant le schema courant, dans l'ordre
    /// attendu par `ModelContainer` / `Schema`.
    public static var models: [any PersistentModel.Type] {
        [Note.self]
    }
}

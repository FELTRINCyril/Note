import Foundation

/// Mode d'hebergement d'une `Database` (Phase 17) : une base peut vivre pleine page
/// (rangee dans un `Folder`, comme une `Note`) ou inline dans une note (portee par un
/// `Block` de type `.databaseView`). Voir `docs/17_base_de_donnees.md`, 17.1.
public enum DatabaseHostMode: String, CaseIterable, Codable, Sendable {
    case fullPage
    case inline
}

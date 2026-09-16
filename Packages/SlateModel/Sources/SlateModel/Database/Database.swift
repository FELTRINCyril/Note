import Foundation
import SwiftData

/// Une collection d'entrees typees (Phase 17, `docs/17_base_de_donnees.md`). Peut vivre
/// **pleine page** (rangee dans un `Folder`, comme une `Note`) ou **inline** dans une
/// note (portee par un `Block` de type `.databaseView`) - voir `DatabaseHostMode`.
///
/// Contraintes CloudKit : toutes les proprietes ont une valeur par defaut ou sont
/// optionnelles ; `folder` et `hostBlock` sont optionnels ; `fields`/`rows` sont
/// optionnels avec une valeur par defaut `[]`.
///
/// ## Un seul type d'entite pour les deux modes, pas deux
///
/// Plutot que deux types distincts (une base "pleine page" et une base "inline"), un
/// seul `Database` porte les deux relations d'hebergement possibles (`folder`,
/// `hostBlock`), toutes deux optionnelles, et `hostMode` documente laquelle est censee
/// etre renseignee. Justification : les champs, les lignes et le moteur de requete
/// (17.4) sont rigoureusement identiques dans les deux modes - seul l'endroit ou la base
/// est accrochee dans l'arborescence change. Dupliquer le modele aurait duplique aussi
/// tout `DatabaseField`/`DatabaseRow`/`DatabaseCell` en deux graphes de relations
/// paralleles pour un gain nul. L'invariant "au plus un des deux est renseigne, celui que
/// `hostMode` designe" n'est pas impose par le schema (SwiftData ne sait pas exprimer une
/// contrainte XOR entre deux relations) : il est du ressort de la couche qui cree une
/// `Database` (future `SlateFeatures`), pas de ce module.
@Model
public final class Database {
    public var id: UUID = UUID()
    public var name: String = ""
    public var iconName: String?
    public var createdAt: Date = Date.now

    public var hostMode: DatabaseHostMode = DatabaseHostMode.fullPage

    /// Dossier porteur pour une base pleine page (`hostMode == .fullPage`). L'inverse
    /// est declare du cote `Folder.databases`.
    public var folder: Folder?

    /// Bloc porteur pour une base inline (`hostMode == .inline`). L'inverse est declare
    /// du cote `Block.databaseView`.
    public var hostBlock: Block?

    /// Champs (colonnes). Supprimer cette base supprime tous ses champs (et, par
    /// cascade, toutes leurs cellules).
    @Relationship(deleteRule: .cascade, inverse: \DatabaseField.database)
    public var fields: [DatabaseField]? = []

    /// Lignes (entrees). Supprimer cette base supprime toutes ses lignes (et, par
    /// cascade, toutes leurs cellules).
    @Relationship(deleteRule: .cascade, inverse: \DatabaseRow.database)
    public var rows: [DatabaseRow]? = []

    public init(
        id: UUID = UUID(),
        name: String = "",
        iconName: String? = nil,
        createdAt: Date = .now,
        hostMode: DatabaseHostMode = .fullPage,
        folder: Folder? = nil,
        hostBlock: Block? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.createdAt = createdAt
        self.hostMode = hostMode
        self.folder = folder
        self.hostBlock = hostBlock
    }

    /// Projection complete (champs + lignes) en valeurs pures, sans dependance
    /// SwiftData, pour `DatabaseQueryEngine`. Champs et lignes tries par `order`.
    public func makeSnapshot() -> DatabaseSnapshot {
        DatabaseSnapshot(
            id: id,
            fields: (fields ?? []).sorted { $0.order < $1.order }.map { $0.makeSnapshot() },
            rows: (rows ?? []).sorted { $0.order < $1.order }.map { $0.makeSnapshot() }
        )
    }
}

import Foundation
import SwiftData

/// Champ (colonne) d'une `Database` (Phase 17). Porte son type et sa configuration ;
/// les valeurs elles-memes sont portees par `DatabaseCell` (sauf pour les types calcules,
/// voir `DatabaseFieldType.storesCellValue`).
///
/// Contraintes CloudKit : toutes les proprietes ont une valeur par defaut ou sont
/// optionnelles ; `database` est optionnel ; `cells` est optionnel avec une valeur par
/// defaut `[]`.
@Model
public final class DatabaseField {
    public var id: UUID = UUID()
    public var name: String = ""

    /// Position parmi les champs de la meme base (ordre des colonnes).
    public var order: Int = 0

    public var fieldType: DatabaseFieldType = DatabaseFieldType.text

    /// Base porteuse. L'inverse est declare du cote `Database.fields`.
    public var database: Database?

    /// Cellules existantes pour ce champ, toutes lignes confondues. Supprimer ce champ
    /// supprime toutes les valeurs saisies pour ce champ (exigence explicite de
    /// `docs/17_base_de_donnees.md`).
    @Relationship(deleteRule: .cascade, inverse: \DatabaseCell.field)
    public var cells: [DatabaseCell]? = []

    /// Stockage brut de `configuration` (voir `DatabaseFieldConfiguration` pour la
    /// justification : `selectOptions` est un tableau, conteneur unkeyed interdit
    /// directement sur une propriete `@Model`).
    private var configurationData: Data?

    @Transient
    public var configuration: DatabaseFieldConfiguration? {
        get {
            guard let configurationData else { return nil }
            return try? JSONDecoder().decode(DatabaseFieldConfiguration.self, from: configurationData)
        }
        set {
            guard let newValue else {
                configurationData = nil
                return
            }
            configurationData = try? JSONEncoder().encode(newValue)
        }
    }

    public init(
        id: UUID = UUID(),
        name: String = "",
        order: Int = 0,
        fieldType: DatabaseFieldType = .text,
        database: Database? = nil,
        configuration: DatabaseFieldConfiguration? = nil
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.fieldType = fieldType
        self.database = database
        self.configuration = configuration
    }

    /// Projection en valeur pure, sans dependance SwiftData, pour `DatabaseQueryEngine`.
    public func makeSnapshot() -> DatabaseFieldSnapshot {
        DatabaseFieldSnapshot(
            id: id,
            name: name,
            order: order,
            type: fieldType,
            configuration: configuration ?? DatabaseFieldConfiguration()
        )
    }
}

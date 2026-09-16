import Foundation

/// Projection en valeur pure d'un `DatabaseField`, sans dependance SwiftData. Consommee
/// par `DatabaseQueryEngine`, qui n'a besoin de rien de plus pour filtrer/trier/grouper.
public struct DatabaseFieldSnapshot: Sendable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var order: Int
    public var type: DatabaseFieldType
    public var configuration: DatabaseFieldConfiguration

    public init(
        id: UUID,
        name: String,
        order: Int,
        type: DatabaseFieldType,
        configuration: DatabaseFieldConfiguration
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.type = type
        self.configuration = configuration
    }
}

/// Projection en valeur pure d'un `DatabaseRow`, sans dependance SwiftData.
public struct DatabaseRowSnapshot: Sendable, Identifiable, Hashable {
    public var id: UUID
    public var order: Int
    public var createdAt: Date
    public var modifiedAt: Date

    /// Valeurs stockees, indexees par `DatabaseField.id`. Ne contient que les champs
    /// dont `DatabaseFieldType.storesCellValue` est vrai et pour lesquels une valeur a
    /// effectivement ete saisie.
    public var values: [UUID: CellValue]

    public init(id: UUID, order: Int, createdAt: Date, modifiedAt: Date, values: [UUID: CellValue]) {
        self.id = id
        self.order = order
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.values = values
    }
}

/// Projection en valeur pure d'une `Database` complete (champs + lignes), sans
/// dependance SwiftData. Point d'entree du moteur de requete (`DatabaseQueryEngine`,
/// 17.4) : construite une fois par `Database.makeSnapshot()`, puis manipulee
/// exclusivement en Swift pur (testable sans `ModelContext`/`ModelContainer`).
public struct DatabaseSnapshot: Sendable, Identifiable, Hashable {
    public var id: UUID
    public var fields: [DatabaseFieldSnapshot]
    public var rows: [DatabaseRowSnapshot]

    public init(id: UUID, fields: [DatabaseFieldSnapshot], rows: [DatabaseRowSnapshot]) {
        self.id = id
        self.fields = fields
        self.rows = rows
    }

    public func field(withID fieldID: UUID) -> DatabaseFieldSnapshot? {
        fields.first { $0.id == fieldID }
    }
}

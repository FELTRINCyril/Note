import Foundation
import SwiftData

/// Une entree (ligne) d'une `Database` (Phase 17).
///
/// Contraintes CloudKit : toutes les proprietes ont une valeur par defaut ou sont
/// optionnelles ; `database` est optionnel ; `cells` est optionnel avec une valeur par
/// defaut `[]`.
@Model
public final class DatabaseRow {
    public var id: UUID = UUID()

    /// Position manuelle parmi les lignes de la meme base (ordre par defaut avant tri
    /// explicite, meme role que `Block.order`).
    public var order: Int = 0

    public var createdAt: Date = Date.now
    public var modifiedAt: Date = Date.now

    /// Base porteuse. L'inverse est declare du cote `Database.rows`.
    public var database: Database?

    /// Valeurs saisies pour cette ligne (une par champ dont
    /// `DatabaseFieldType.storesCellValue` est vrai). Supprimer cette ligne supprime
    /// toutes ses valeurs.
    @Relationship(deleteRule: .cascade, inverse: \DatabaseCell.row)
    public var cells: [DatabaseCell]? = []

    public init(
        id: UUID = UUID(),
        order: Int = 0,
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        database: Database? = nil
    ) {
        self.id = id
        self.order = order
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.database = database
    }

    /// Valeur actuelle pour `fieldID`, `nil` si aucune cellule n'existe encore pour ce
    /// champ sur cette ligne.
    public func cellValue(forFieldID fieldID: UUID) -> CellValue? {
        cells?.first(where: { $0.field?.id == fieldID })?.value
    }

    /// Ecrit la valeur de `field` pour cette ligne : met a jour la `DatabaseCell`
    /// existante si elle existe, en cree une sinon. Met aussi a jour `modifiedAt`.
    ///
    /// Ne fait aucune insertion dans un `ModelContext` pour la cellule creee : comme le
    /// reste du modele (voir `EntityGraphTests`), c'est a l'appelant d'inserer une
    /// cellule nouvellement creee.
    @discardableResult
    public func setCellValue(_ value: CellValue?, for field: DatabaseField) -> DatabaseCell {
        modifiedAt = .now
        if let existing = cells?.first(where: { $0.field?.id == field.id }) {
            existing.value = value
            return existing
        }
        let cell = DatabaseCell(row: self, field: field, value: value)
        cells?.append(cell)
        return cell
    }

    /// Projection en valeur pure, sans dependance SwiftData, pour `DatabaseQueryEngine`.
    /// Ne conserve que les valeurs non `nil` (une cellule existante avec une valeur
    /// effacee equivaut a une absence de valeur).
    public func makeSnapshot() -> DatabaseRowSnapshot {
        var values: [UUID: CellValue] = [:]
        for cell in cells ?? [] {
            guard let fieldID = cell.field?.id, let value = cell.value else { continue }
            values[fieldID] = value
        }
        return DatabaseRowSnapshot(id: id, order: order, createdAt: createdAt, modifiedAt: modifiedAt, values: values)
    }
}

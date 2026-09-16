import Foundation
import SwiftData

/// Valeur d'un champ pour une ligne donnee (Phase 17). Existe uniquement pour les types
/// de champ dont `DatabaseFieldType.storesCellValue` est vrai ; les champs calcules
/// (`createdDate`, `modifiedDate`, `rollup`) n'ont jamais de `DatabaseCell`.
///
/// Contraintes CloudKit : toutes les proprietes ont une valeur par defaut ou sont
/// optionnelles ; `row` et `field` sont optionnels.
///
/// Deux relations to-one optionnelles (`row`, `field`) plutot qu'une cle composite : une
/// cellule "appartient" a la fois a une ligne et a un champ, chacun cote proprietaire de
/// son propre `@Relationship(deleteRule: .cascade)` (voir `DatabaseRow.cells` et
/// `DatabaseField.cells`) - supprimer soit la ligne, soit le champ, supprime la cellule.
@Model
public final class DatabaseCell {
    public var id: UUID = UUID()

    /// Ligne porteuse. L'inverse est declare du cote `DatabaseRow.cells`.
    public var row: DatabaseRow?

    /// Champ porteur. L'inverse est declare du cote `DatabaseField.cells`.
    public var field: DatabaseField?

    /// Stockage brut de `value` (voir `CellValue` pour la justification de ce
    /// contournement : conteneurs unkeyed imbriques pour `.multiSelect`/`.relation`,
    /// piege n°2 de `docs/DEV_ENV.md`).
    private var valueData: Data?

    @Transient
    public var value: CellValue? {
        get {
            guard let valueData else { return nil }
            return try? JSONDecoder().decode(CellValue.self, from: valueData)
        }
        set {
            guard let newValue else {
                valueData = nil
                return
            }
            valueData = try? JSONEncoder().encode(newValue)
        }
    }

    public init(
        id: UUID = UUID(),
        row: DatabaseRow? = nil,
        field: DatabaseField? = nil,
        value: CellValue? = nil
    ) {
        self.id = id
        self.row = row
        self.field = field
        self.value = value
    }
}

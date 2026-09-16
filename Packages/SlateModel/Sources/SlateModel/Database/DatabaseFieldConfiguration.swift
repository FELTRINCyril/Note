import Foundation

/// Format d'affichage d'un champ `.number` (`DatabaseFieldConfiguration.numberFormat`).
public enum DatabaseNumberFormat: String, CaseIterable, Codable, Sendable {
    case plain
    case integer
    case percent
    case currency
}

/// Option d'un champ `.singleSelect`/`.multiSelect`. `colorToken` est un identifiant
/// textuel neutre (meme motif que `BlockAttributes.calloutVariant`) : `SlateModel` ne
/// connait aucune notion d'apparence, seule `SlateUI` resout ce token en couleur reelle.
public struct DatabaseSelectOption: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var label: String
    public var colorToken: String

    public init(id: UUID = UUID(), label: String, colorToken: String) {
        self.id = id
        self.label = label
        self.colorToken = colorToken
    }
}

/// Operation d'agregation d'un champ `.rollup` a travers une relation.
public enum DatabaseRollupOperation: String, CaseIterable, Codable, Sendable {
    case count
    case countFilled
    case countEmpty
    case sum
    case average
    case min
    case max
    case percentFilled
    case percentEmpty
}

/// Configuration propre a un champ (`DatabaseField.configuration`) : options d'une
/// selection, format d'un nombre, base cible d'une relation, champ et operation d'un
/// rollup.
///
/// Stockee en `Data` (JSON) par `DatabaseField`, jamais directement comme propriete
/// `@Model` : `selectOptions` est un tableau, donc un conteneur unkeyed dans son
/// encodage. Meme raisonnement et meme contournement que `CellValue`, voir sa
/// documentation de tete.
///
/// Toutes les proprietes sont optionnelles : une meme configuration porte les reglages
/// de plusieurs types de champ possibles (seul le sous-ensemble pertinent pour
/// `DatabaseField.fieldType` est renseigne), et une configuration vide (`nil` partout)
/// est un etat valide (champ qui vient d'etre cree).
public struct DatabaseFieldConfiguration: Codable, Hashable, Sendable {
    /// Format d'un champ `.number`. `nil` = `.plain`.
    public var numberFormat: DatabaseNumberFormat?

    /// Options disponibles d'un champ `.singleSelect`/`.multiSelect`, dans leur ordre
    /// d'affichage (ordre du tableau, pas de champ `order` dedie).
    public var selectOptions: [DatabaseSelectOption]?

    /// Base ciblee par un champ `.relation`.
    public var relationTargetDatabaseID: UUID?

    /// Champ `.relation` de la MEME base a suivre pour un champ `.rollup`.
    public var rollupSourceFieldID: UUID?
    /// Champ de la base ciblee par `rollupSourceFieldID` dont la valeur est agregee.
    public var rollupTargetFieldID: UUID?
    /// Operation d'agregation appliquee aux valeurs de `rollupTargetFieldID`.
    public var rollupOperation: DatabaseRollupOperation?

    public init(
        numberFormat: DatabaseNumberFormat? = nil,
        selectOptions: [DatabaseSelectOption]? = nil,
        relationTargetDatabaseID: UUID? = nil,
        rollupSourceFieldID: UUID? = nil,
        rollupTargetFieldID: UUID? = nil,
        rollupOperation: DatabaseRollupOperation? = nil
    ) {
        self.numberFormat = numberFormat
        self.selectOptions = selectOptions
        self.relationTargetDatabaseID = relationTargetDatabaseID
        self.rollupSourceFieldID = rollupSourceFieldID
        self.rollupTargetFieldID = rollupTargetFieldID
        self.rollupOperation = rollupOperation
    }
}

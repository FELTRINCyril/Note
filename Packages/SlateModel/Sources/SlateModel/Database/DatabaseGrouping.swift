import Foundation

/// Cle d'un groupe produit par `DatabaseQueryEngine.group`. Volontairement une enum
/// fermee plutot qu'un `CellValue` brut : un groupe n'a pas besoin de porter une date
/// complete ou un nombre a virgule flottante arbitraire, seulement une cle stable et
/// comparable - voir les cas `.text`/`.number` ci-dessous, deja normalises.
public enum DatabaseGroupKey: Sendable, Hashable {
    /// Option choisie (champ `.singleSelect`/`.multiSelect`), voir
    /// `DatabaseSelectOption.id`.
    case option(UUID)
    /// Champ `.checkbox`.
    case boolean(Bool)
    /// Champ `.text`/`.url`, ou jour calendaire d'un champ `.date` (forme "AAAA-MM-JJ",
    /// choisie pour rester independante du fuseau/de la locale d'affichage).
    case text(String)
    /// Champ `.number`.
    case number(Double)
    /// Aucune valeur saisie pour ce champ sur cette ligne.
    case empty
}

/// Un groupe de lignes partageant la meme `DatabaseGroupKey` pour un champ donne. Base
/// commune a la vue Kanban (colonnes = groupes, 17.5) et a un futur regroupement de la
/// vue Grille.
public struct DatabaseGroup: Sendable {
    public var key: DatabaseGroupKey
    public var rows: [DatabaseRowSnapshot]

    public init(key: DatabaseGroupKey, rows: [DatabaseRowSnapshot]) {
        self.key = key
        self.rows = rows
    }
}

extension DatabaseQueryEngine {
    /// Regroupe `rows` par la valeur effective du champ `fieldID`.
    ///
    /// Un champ `.multiSelect` fait apparaitre une meme ligne dans **plusieurs**
    /// groupes (un par option selectionnee) : c'est le comportement attendu d'un
    /// regroupement par etiquettes multiples (une tache tagguee "Urgent" et
    /// "Facturation" doit apparaitre dans les deux colonnes Kanban correspondantes).
    /// Un champ `.relation` groupe seulement par "vide"/"rempli" : grouper par ligne
    /// ciblee individuellement n'aurait pas de libelle stable sans resoudre la base
    /// distante, hors de portee de cette fonction.
    ///
    /// Ordre des groupes retourne : pour un champ `.singleSelect`/`.multiSelect`,
    /// l'ordre des options dans `DatabaseFieldConfiguration.selectOptions` ; pour les
    /// autres types, l'ordre de premiere apparition dans `rows`. Le groupe `.empty` est
    /// toujours place en dernier, quel que soit le type de champ.
    public static func group(
        _ rows: [DatabaseRowSnapshot],
        by fieldID: UUID,
        fields: [DatabaseFieldSnapshot],
        relatedDatabases: [UUID: DatabaseSnapshot] = [:]
    ) -> [DatabaseGroup] {
        guard let field = fields.first(where: { $0.id == fieldID }) else { return [] }

        var buckets: [DatabaseGroupKey: [DatabaseRowSnapshot]] = [:]
        var order: [DatabaseGroupKey] = []

        for row in rows {
            let value = evaluatedValue(for: fieldID, in: row, fields: fields, relatedDatabases: relatedDatabases)
            for key in groupKeys(for: value) {
                if buckets[key] == nil {
                    buckets[key] = []
                    order.append(key)
                }
                buckets[key]?.append(row)
            }
        }

        return orderedKeys(order, selectOptions: field.configuration.selectOptions)
            .map { DatabaseGroup(key: $0, rows: buckets[$0] ?? []) }
    }

    private static func groupKeys(for value: CellValue?) -> [DatabaseGroupKey] {
        guard let value, !value.isEmpty else { return [.empty] }
        switch value {
        case .text(let text), .url(let text):
            return [.text(text)]
        case .number(let number):
            return [.number(number)]
        case .date(let date):
            let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            let day = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
            return [.text(day)]
        case .checkbox(let flag):
            return [.boolean(flag)]
        case .singleSelect(let optionID):
            return [.option(optionID)]
        case .multiSelect(let optionIDs):
            return optionIDs.isEmpty ? [.empty] : optionIDs.map { .option($0) }
        case .relation(let rowIDs):
            return [.boolean(!rowIDs.isEmpty)]
        }
    }

    private static func orderedKeys(
        _ keys: [DatabaseGroupKey],
        selectOptions: [DatabaseSelectOption]?
    ) -> [DatabaseGroupKey] {
        let withoutEmpty = keys.filter { $0 != .empty }
        let hasEmpty = keys.contains(.empty)

        guard let selectOptions else { return hasEmpty ? withoutEmpty + [.empty] : withoutEmpty }

        let optionOrder = selectOptions.map(\.id)
        let sorted = withoutEmpty.sorted { lhs, rhs in
            guard case .option(let leftID) = lhs, case .option(let rightID) = rhs else { return false }
            let leftIndex = optionOrder.firstIndex(of: leftID) ?? Int.max
            let rightIndex = optionOrder.firstIndex(of: rightID) ?? Int.max
            return leftIndex < rightIndex
        }
        return hasEmpty ? sorted + [.empty] : sorted
    }
}

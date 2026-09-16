import Foundation

/// Valeur d'une cellule de base de donnees (`DatabaseCell.value`), Phase 17.
///
/// ## Decision structurante : enum associe, stocke en `Data` (JSON), jamais directement
/// comme propriete `@Model`
///
/// La valeur d'une cellule est fondamentalement heterogene selon le type du champ
/// porteur (texte, nombre, date, case a cocher, URL, une option, plusieurs options,
/// des references de lignes). Un enum `Codable` a cas associes est la representation
/// Swift la plus naturelle - mais son encodage synthetise produit un conteneur garde
/// par cle au niveau du cas puis, pour `.multiSelect`/`.relation`, un tableau (conteneur
/// **unkeyed**) imbrique pour la valeur associee. C'est exactement le piege n°2 de
/// `docs/DEV_ENV.md` (`Composite Coder only supports Keyed Container`, `fatalError` au
/// premier acces, pas une erreur de compilation) si ce type etait stocke directement
/// comme propriete `@Model`.
///
/// Le contournement retenu est identique a celui deja en place pour `Block.text`
/// (`RichText`, voir `Block.swift`) et pour `Database.configuration`
/// (`DatabaseFieldConfiguration`) : `DatabaseCell` ne stocke qu'un `Data?` prive
/// (`valueData`), et expose cette enum via un accesseur calcule qui encode/decode
/// explicitement en JSON, **hors** du chemin interne de persistance de SwiftData (le
/// "composite coder" ne voit jamais qu'un `Data?`, un type primitif sans ambiguite pour
/// SwiftData/CloudKit). Une fois isole dans un blob opaque, la structure interne de
/// l'encodage (unkeyed ou non) n'a plus d'importance : c'est pour cela que cette enum
/// peut rester un `Codable` synthetise simple, sans `CodingKeys`/`init(from:)` ecrits a
/// la main (a la difference de `BlockAttributes`, qui elle EST flattenee directement par
/// SwiftData et doit donc rester deliberement retro-compatible champ par champ).
public enum CellValue: Codable, Hashable, Sendable {
    /// Texte libre (champ `.text`, mais aussi valeur affichable d'un champ `.url`).
    case text(String)
    /// Valeur numerique (champ `.number`).
    case number(Double)
    /// Date (champ `.date`). Les champs calcules `.createdDate`/`.modifiedDate` ne
    /// passent jamais par une `DatabaseCell` : voir `DatabaseRow.createdAt`/`modifiedAt`
    /// et `DatabaseQueryEngine.evaluatedValue`.
    case date(Date)
    /// Case a cocher (champ `.checkbox`).
    case checkbox(Bool)
    /// URL, stockee en `String` brute (pas `Foundation.URL`) : une valeur saisie
    /// partiellement/invalide reste representable sans echec de decodage.
    case url(String)
    /// Option choisie (champ `.singleSelect`), identifiant d'une
    /// `DatabaseSelectOption.id` de la configuration du champ.
    case singleSelect(UUID)
    /// Options choisies (champ `.multiSelect`), memes identifiants que `.singleSelect`.
    case multiSelect([UUID])
    /// Lignes ciblees (champ `.relation`), identifiants de `DatabaseRow.id` dans la base
    /// cible (`DatabaseFieldConfiguration.relationTargetDatabaseID`).
    case relation([UUID])

    /// Vrai si cette valeur est consideree "vide" par les operateurs de filtre
    /// `isEmpty`/`isNotEmpty` et par les calculs de colonne (`countFilled`/`countEmpty`).
    public var isEmpty: Bool {
        switch self {
        case .text(let value), .url(let value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .number, .date, .checkbox, .singleSelect:
            return false
        case .multiSelect(let ids), .relation(let ids):
            return ids.isEmpty
        }
    }
}

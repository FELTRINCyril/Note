import Foundation
import SwiftData

/// Points d'entree de suppression pour le modele base de donnees, qui font respecter
/// les invariants exiges par `docs/17_base_de_donnees.md` :
/// - supprimer un champ nettoie les valeurs correspondantes (cascade `DatabaseField.cells`) ;
/// - supprimer une ligne ou une base ne laisse aucun orphelin (cascades `@Relationship`) ;
/// - **une relation dont la cible disparait ne doit pas produire de reference morte
///   silencieuse** : ce dernier point n'est PAS couvert par une cascade SwiftData, une
///   valeur de champ `.relation` n'etant qu'un tableau d'`UUID` dans un blob JSON
///   (`CellValue.relation`, voir sa documentation), pas une vraie relation d'objets que
///   SwiftData saurait nettoyer seule a la suppression. Ces fonctions le font
///   explicitement, en parcourant les bases "liees" passees par l'appelant (ce module ne
///   peut pas les decouvrir seul : il n'existe pas de relation objet entre deux
///   `Database` distinctes, seulement un `UUID` de configuration).
///
/// **A l'attention de l'appelant (future couche de service)** : toujours passer par ces
/// fonctions plutot que par `context.delete(...)` directement des lors qu'un champ
/// `.relation`/`.rollup` est susceptible d'exister quelque part dans l'espace de
/// travail - sans quoi le piege n°3 de `docs/DEV_ENV.md` (detacher n'est pas supprimer)
/// se doublerait ici d'un second risque, une reference `UUID` orpheline invisible tant
/// qu'on ne cherche pas a la resoudre.
extension Database {
    /// Supprime `row` de sa base, et nettoie toute reference a `row.id` dans les champs
    /// `.relation` de `relatedDatabases` (et de la base porteuse de `row` elle-meme,
    /// pour une auto-relation) qui la ciblaient.
    public static func deleteRow(
        _ row: DatabaseRow,
        from context: ModelContext,
        relatedDatabases: [Database] = []
    ) {
        let deletedID = row.id
        var candidates = relatedDatabases
        if let hostDatabase = row.database, !candidates.contains(where: { $0.id == hostDatabase.id }) {
            candidates.append(hostDatabase)
        }

        for database in candidates {
            for field in database.fields ?? [] where field.fieldType == .relation {
                for cell in field.cells ?? [] {
                    guard case .relation(var referencedIDs)? = cell.value else { continue }
                    guard referencedIDs.contains(deletedID) else { continue }
                    referencedIDs.removeAll { $0 == deletedID }
                    cell.value = .relation(referencedIDs)
                }
            }
        }

        context.delete(row)
    }

    /// Supprime `field` de sa base (ses cellules disparaissent par cascade, voir
    /// `DatabaseField.cells`), et desamorce tout champ `.rollup` de `relatedDatabases`
    /// (et de la base porteuse) qui le referencait comme relation source ou champ cible.
    public static func deleteField(
        _ field: DatabaseField,
        from context: ModelContext,
        relatedDatabases: [Database] = []
    ) {
        let deletedID = field.id
        var candidates = relatedDatabases
        if let hostDatabase = field.database, !candidates.contains(where: { $0.id == hostDatabase.id }) {
            candidates.append(hostDatabase)
        }

        for database in candidates {
            for otherField in database.fields ?? [] where otherField.fieldType == .rollup {
                guard var configuration = otherField.configuration else { continue }
                let referencesDeletedField = configuration.rollupSourceFieldID == deletedID
                    || configuration.rollupTargetFieldID == deletedID
                guard referencesDeletedField else { continue }
                configuration.rollupSourceFieldID = nil
                configuration.rollupTargetFieldID = nil
                configuration.rollupOperation = nil
                otherField.configuration = configuration
            }
        }

        context.delete(field)
    }

    /// Supprime `database` entierement (champs, lignes et cellules disparaissent par
    /// cascade), et desamorce tout champ `.relation` de `relatedDatabases` qui la
    /// ciblait (efface `relationTargetDatabaseID` et vide les valeurs deja saisies,
    /// puisque les lignes qu'elles referencaient n'existent plus).
    public static func delete(
        _ database: Database,
        from context: ModelContext,
        relatedDatabases: [Database] = []
    ) {
        let deletedID = database.id

        for other in relatedDatabases where other.id != deletedID {
            for field in other.fields ?? [] where field.fieldType == .relation {
                guard var configuration = field.configuration else { continue }
                guard configuration.relationTargetDatabaseID == deletedID else { continue }
                configuration.relationTargetDatabaseID = nil
                field.configuration = configuration
                for cell in field.cells ?? [] {
                    cell.value = nil
                }
            }
        }

        context.delete(database)
    }
}

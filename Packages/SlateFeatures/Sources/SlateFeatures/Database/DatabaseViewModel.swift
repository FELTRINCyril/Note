import Foundation
import Observation
import SlateModel
import SlateUI
import SwiftData

/// Etat et logique de toutes les vues d'une `Database` (Phase 17, sous-etapes 17.3/17.4/
/// 17.5/17.6). Un seul modele d'etat partage par les 5 vues (Grille/Kanban/Calendrier/
/// Galerie/Liste) : c'est ce partage qui garantit le critere d'acceptation "basculer
/// entre les 5 vues sur les MEMES donnees" (memes filtres/tris/groupement quelle que
/// soit la vue active, voir `docs/17_base_de_donnees.md`).
///
/// Toute mutation (CRUD ligne/champ/cellule) passe par ce type, jamais directement par
/// une vue : c'est ICI que vivent les regles d'integrite (voir `Database+Integrity.swift`,
/// `SlateModel`) - une vue ne doit jamais appeler `modelContext.delete(...)` elle-meme
/// sur une ligne/un champ/une base.
///
/// L'etat d'affichage (vue active, filtre, tri, groupement, largeurs de colonnes) est
/// volontairement EN MEMOIRE seulement (pas persiste) : `SlateModel` ne porte aucune
/// entite dediee a cet etat (hors perimetre de cette phase), et le persister via un
/// mecanisme parallele (UserDefaults par base) aurait ajoute une source de verite de
/// plus pour un gain mineur (le prochain document de base repart de la vue Grille,
/// comme un tableur qui rouvre sur son premier onglet). Documente comme limite connue.
@MainActor
@Observable
public final class DatabaseViewModel {
    public let database: Database
    private let modelContext: ModelContext

    /// Autres bases de l'espace de travail, necessaires a la resolution des champs
    /// `.relation`/`.rollup` (`DatabaseQueryEngine`, parametre `relatedDatabases`).
    /// Fournie par l'appelant : ce type n'a pas connaissance d'un espace de travail
    /// complet, seulement de la base qu'il pilote.
    public var relatedDatabases: [Database]

    public var viewKind: SlateDatabaseViewKind = .grid
    public var filter = DatabaseFilter()
    public var sortDescriptors: [DatabaseSortDescriptor] = []
    public var groupFieldID: UUID?
    public var columnCalculations: [UUID: SlateDatabaseColumnCalculation] = [:]
    public var columnWidths: [UUID: CGFloat] = [:]
    public var columnOrder: [UUID] = []

    /// Champ de date utilise par la vue Calendrier (17.5) : le premier champ `.date`/
    /// `.createdDate`/`.modifiedDate` de la base par defaut, modifiable par l'utilisateur
    /// depuis la barre de navigation du calendrier.
    public var calendarFieldID: UUID?
    public var calendarMonthAnchor: Date = .now

    public var galleryThumbnailSize: SlateDatabaseGalleryThumbnailSize = .small

    public init(database: Database, modelContext: ModelContext, relatedDatabases: [Database] = []) {
        self.database = database
        self.modelContext = modelContext
        self.relatedDatabases = relatedDatabases
        let snapshot = database.makeSnapshot()
        self.columnOrder = snapshot.fields.sorted { $0.order < $1.order }.map(\.id)
        self.calendarFieldID = snapshot.fields.first {
            $0.type == .date || $0.type == .createdDate || $0.type == .modifiedDate
        }?.id
    }

    // MARK: - Lecture (moteur de requete)

    public var snapshot: DatabaseSnapshot { database.makeSnapshot() }

    /// Champs dans l'ordre d'affichage des colonnes (`columnOrder`), avec repli sur
    /// `order` pour tout champ absent de `columnOrder` (ex. champ ajoute apres coup).
    public var orderedFields: [DatabaseFieldSnapshot] {
        let byID = Dictionary(uniqueKeysWithValues: snapshot.fields.map { ($0.id, $0) })
        var seen = Set<UUID>()
        var result: [DatabaseFieldSnapshot] = []
        for id in columnOrder {
            guard let field = byID[id] else { continue }
            result.append(field)
            seen.insert(id)
        }
        result.append(contentsOf: snapshot.fields.filter { !seen.contains($0.id) }.sorted { $0.order < $1.order })
        return result
    }

    /// Lignes filtrees puis triees : la source unique consommee par les 5 vues.
    public var visibleRows: [DatabaseRowSnapshot] {
        let related = relatedDatabaseMap
        let fields = snapshot.fields
        let filtered = DatabaseQueryEngine.filter(
            snapshot.rows, with: filter, fields: fields, relatedDatabases: related
        )
        return DatabaseQueryEngine.sort(filtered, by: sortDescriptors, fields: fields, relatedDatabases: related)
    }

    public var groups: [DatabaseGroup] {
        guard let groupFieldID else { return [] }
        return DatabaseQueryEngine.group(
            visibleRows, by: groupFieldID, fields: snapshot.fields, relatedDatabases: relatedDatabaseMap
        )
    }

    public func calculationResult(for fieldID: UUID) -> DatabaseCalculationResult {
        let calculation = columnCalculations[fieldID] ?? .none
        return DatabaseQueryEngine.calculate(
            calculation.engineCalculation,
            fieldID: fieldID,
            in: visibleRows,
            fields: snapshot.fields,
            relatedDatabases: relatedDatabaseMap
        )
    }

    public func evaluatedValue(fieldID: UUID, row: DatabaseRowSnapshot) -> CellValue? {
        DatabaseQueryEngine.evaluatedValue(
            for: fieldID, in: row, fields: snapshot.fields, relatedDatabases: relatedDatabaseMap
        )
    }

    private var relatedDatabaseMap: [UUID: DatabaseSnapshot] {
        Dictionary(uniqueKeysWithValues: relatedDatabases.map { ($0.id, $0.makeSnapshot()) })
    }

    // MARK: - CRUD lignes

    @discardableResult
    public func addRow(prefilledWith values: [UUID: CellValue] = [:]) -> DatabaseRow {
        let row = DatabaseRow(order: (database.rows?.count ?? 0), database: database)
        modelContext.insert(row)
        database.rows?.append(row)
        for field in database.fields ?? [] {
            guard let value = values[field.id] else { continue }
            let cell = row.setCellValue(value, for: field)
            if cell.modelContext == nil { modelContext.insert(cell) }
        }
        save()
        return row
    }

    public func deleteRow(_ rowID: UUID) {
        guard let row = database.rows?.first(where: { $0.id == rowID }) else { return }
        Database.deleteRow(row, from: modelContext, relatedDatabases: relatedDatabases)
        save()
    }

    public func setCellValue(_ value: CellValue?, rowID: UUID, fieldID: UUID) {
        guard let row = database.rows?.first(where: { $0.id == rowID }) else { return }
        guard let field = database.fields?.first(where: { $0.id == fieldID }) else { return }
        let cell = row.setCellValue(value, for: field)
        if cell.modelContext == nil { modelContext.insert(cell) }
        save()
    }

    /// Deplace `rowID` vers le groupe `key` d'un champ de selection (Kanban, 17.5 :
    /// "deplacer une carte d'une colonne a l'autre met a jour le champ de regroupement").
    /// Sans effet si le champ de regroupement n'est pas une selection (le glisser-depose
    /// Kanban n'a de sens que pour `.singleSelect` aujourd'hui, voir sa vue).
    public func moveRow(_ rowID: UUID, toGroup optionID: UUID?, fieldID: UUID) {
        let field = database.fields?.first(where: { $0.id == fieldID })
        guard field?.fieldType == .singleSelect else { return }
        let value = optionID.map { CellValue.singleSelect($0) }
        setCellValue(value, rowID: rowID, fieldID: fieldID)
    }

    // MARK: - CRUD champs

    @discardableResult
    public func addField(name: String, type: DatabaseFieldType) -> DatabaseField {
        let field = DatabaseField(name: name, order: database.fields?.count ?? 0, fieldType: type, database: database)
        modelContext.insert(field)
        database.fields?.append(field)
        columnOrder.append(field.id)
        save()
        return field
    }

    public func deleteField(_ fieldID: UUID) {
        guard let field = database.fields?.first(where: { $0.id == fieldID }) else { return }
        Database.deleteField(field, from: modelContext, relatedDatabases: relatedDatabases)
        columnOrder.removeAll { $0 == fieldID }
        columnCalculations.removeValue(forKey: fieldID)
        columnWidths.removeValue(forKey: fieldID)
        save()
    }

    public func renameField(_ fieldID: UUID, to name: String) {
        guard let field = database.fields?.first(where: { $0.id == fieldID }) else { return }
        field.name = name
        save()
    }

    /// Change le type d'un champ. Efface les cellules existantes : une valeur saisie
    /// pour un type (ex. un `UUID` de `.singleSelect`) n'a en general aucun sens pour un
    /// autre (ex. `.number`) - repartir vide est plus honnete qu'un affichage incoherent.
    public func changeFieldType(_ fieldID: UUID, to type: DatabaseFieldType) {
        guard let field = database.fields?.first(where: { $0.id == fieldID }) else { return }
        field.fieldType = type
        for cell in field.cells ?? [] { cell.value = nil }
        save()
    }

    public func updateFieldConfiguration(_ fieldID: UUID, _ configuration: DatabaseFieldConfiguration) {
        guard let field = database.fields?.first(where: { $0.id == fieldID }) else { return }
        field.configuration = configuration
        save()
    }

    public func moveColumn(_ fieldID: UUID, before targetID: UUID) {
        var order = orderedFields.map(\.id)
        order.removeAll { $0 == fieldID }
        guard let targetIndex = order.firstIndex(of: targetID) else { return }
        order.insert(fieldID, at: targetIndex)
        columnOrder = order
    }

    // MARK: - Templates (17.6)

    public var templates: [DatabaseTemplate] { DatabaseTemplateStore.templates(for: database.id) }

    public func saveTemplate(_ template: DatabaseTemplate) {
        DatabaseTemplateStore.addOrUpdate(template, for: database.id)
    }

    public func deleteTemplate(_ templateID: UUID) {
        DatabaseTemplateStore.delete(templateID, for: database.id)
    }

    @discardableResult
    public func applyTemplate(_ template: DatabaseTemplate) -> DatabaseRow {
        addRow(prefilledWith: template.values)
    }

    private func save() {
        try? modelContext.save()
    }
}

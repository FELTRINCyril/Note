import Foundation
import SlateModel

/// Une fiche pre-remplie reutilisable en un clic pour une nouvelle entree (17.6,
/// `docs/17_base_de_donnees.md`).
///
/// `SlateModel` ne porte aucune entite "template" (perimetre confie a `data-modeler`,
/// non livre pour cette phase) : plutot que d'ajouter une entite SwiftData hors du
/// perimetre confie a cet agent, un template est une petite valeur `Codable` persistee
/// par `DatabaseTemplateStore` (fichier JSON, un par base, cote `SlateFeatures`). Limite
/// assumee : un template ne survit pas a la suppression de son fichier local (pas de
/// synchronisation CloudKit) - acceptable pour une phase dont le critere d'acceptation
/// est "templates operationnels", pas "templates synchronises".
public struct DatabaseTemplate: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var values: [UUID: CellValue]

    public init(id: UUID = UUID(), name: String, values: [UUID: CellValue] = [:]) {
        self.id = id
        self.name = name
        self.values = values
    }
}

/// Persistance des templates d'une base, un fichier JSON par `Database.id` dans
/// Application Support. Facade sans etat (comme `DatabaseQueryEngine`) : chaque appel
/// relit/reecrit le fichier, une base de donnees n'ayant jamais plus qu'une poignee de
/// templates, la simplicite prime sur la mise en cache.
enum DatabaseTemplateStore {
    static func templates(for databaseID: UUID) -> [DatabaseTemplate] {
        guard let url = fileURL(for: databaseID), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([DatabaseTemplate].self, from: data)) ?? []
    }

    static func save(_ templates: [DatabaseTemplate], for databaseID: UUID) {
        guard let url = fileURL(for: databaseID) else { return }
        guard let data = try? JSONEncoder().encode(templates) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }

    static func addOrUpdate(_ template: DatabaseTemplate, for databaseID: UUID) {
        var current = templates(for: databaseID)
        if let index = current.firstIndex(where: { $0.id == template.id }) {
            current[index] = template
        } else {
            current.append(template)
        }
        save(current, for: databaseID)
    }

    static func delete(_ templateID: UUID, for databaseID: UUID) {
        let remaining = templates(for: databaseID).filter { $0.id != templateID }
        save(remaining, for: databaseID)
    }

    private static func fileURL(for databaseID: UUID) -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        return base
            .appendingPathComponent("Slate", isDirectory: true)
            .appendingPathComponent("DatabaseTemplates", isDirectory: true)
            .appendingPathComponent("\(databaseID.uuidString).json")
    }
}

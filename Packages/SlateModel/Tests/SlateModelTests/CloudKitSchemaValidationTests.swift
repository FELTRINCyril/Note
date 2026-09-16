import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Verifie que le schema complet (11 entites depuis la Phase 17, voir
/// `SlateSchema.swift`) respecte les deux contraintes CloudKit
/// rappelees par `docs/DEV_ENV.md` et `docs/02_modele_donnees.md` :
/// - toute propriete (attribut) non optionnelle a une valeur par defaut ;
/// - toute relation est optionnelle.
///
/// ## Pourquoi ce test n'invoque pas reellement `cloudKitDatabase: .private(...)`
///
/// La premiere version de ce test construisait une vraie `ModelConfiguration` avec
/// `cloudKitDatabase: .private(...)` et appelait `ModelContainer(for:configurations:)`,
/// comme le suggere `docs/02_modele_donnees.md`. Constat reproduit deux fois de suite :
/// cet appel ne leve **pas** une erreur Swift propre en cas de probleme, il fait
/// **planter tout le process de test** (`NSInternalInconsistencyException:
/// "bundleIdentifier != nil"`, remontee depuis PushKit/CloudKit au moment ou SwiftData
/// tente d'enregistrer les notifications push necessaires a la synchronisation).
/// L'executable de test `swift test` (SPM) n'est pas un bundle applicatif avec un
/// identifiant, contrairement a `Slate.app` : CloudKit refuse donc de s'initialiser ici,
/// quelle que soit la validite du schema. Ce n'est donc pas testable "en vrai" dans cet
/// environnement (confirme : il faudrait un compte developpeur Apple, un container
/// iCloud provisionne et des entitlements signes, ce qui sort du cadre d'un test
/// unitaire SPM). Le dire clairement ici plutot que de garder un test qui plante toute
/// la suite pour un gain de couverture illusoire.
///
/// ## Ce que ce test verifie reellement, honnetement
///
/// Il inspecte le `Schema` reel construit par SwiftData a partir des 7 `@Model` de
/// `SlateSchemaV1` (pas une relecture de la documentation, le schema tel que SwiftData
/// le voit au runtime) et affirme, pour chaque entite :
/// - chaque `Schema.Attribute` est `isOptional == true` OU a un `defaultValue` non nil ;
/// - chaque `Schema.Relationship` est `isOptional == true`.
/// C'est exactement la partie "locale" (sans reseau, sans compte iCloud) de la
/// validation CloudKit que SwiftData effectuerait lui-meme au chargement d'un store
/// CloudKit : les deux memes conditions.
struct CloudKitSchemaValidationTests {

    @Test
    func everyAttributeIsOptionalOrHasADefaultValue() throws {
        let schema = Schema(versionedSchema: SlateSchemaV1.self)

        var offendingAttributes: [String] = []
        for entity in schema.entities {
            for property in entity.properties {
                guard let attribute = property as? Schema.Attribute else { continue }
                let hasDefault = attribute.defaultValue != nil
                if !attribute.isOptional && !hasDefault {
                    offendingAttributes.append("\(entity.name).\(attribute.name)")
                }
            }
        }

        #expect(offendingAttributes.isEmpty, "Proprietes sans defaut ni optionnalite : \(offendingAttributes)")
    }

    @Test
    func everyRelationshipIsOptional() throws {
        let schema = Schema(versionedSchema: SlateSchemaV1.self)

        var offendingRelationships: [String] = []
        for entity in schema.entities {
            for property in entity.properties {
                guard let relationship = property as? Schema.Relationship else { continue }
                if !relationship.isOptional {
                    offendingRelationships.append("\(entity.name).\(relationship.name)")
                }
            }
        }

        #expect(offendingRelationships.isEmpty, "Relations non optionnelles : \(offendingRelationships)")
    }

    @Test
    func allElevenEntitiesAreRegisteredInTheSchema() {
        let schema = Schema(versionedSchema: SlateSchemaV1.self)
        let entityNames = Set(schema.entities.map { $0.name })

        #expect(entityNames == [
            "Workspace", "Space", "Folder", "Note", "Block", "Attachment", "Tag",
            "Database", "DatabaseField", "DatabaseRow", "DatabaseCell"
        ])
    }
}

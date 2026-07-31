import Foundation
import SwiftData

/// Identifiant du container iCloud utilise par Slate pour la synchronisation
/// CloudKit (capability "iCloud -> CloudKit", voir docs/01_setup_projet.md 1.4).
private let cloudKitContainerIdentifier = "iCloud.com.gemaddis.slate"

/// Fabrique du `ModelContainer` central de l'app.
///
/// CloudKit n'est active que si le flag de compilation `SLATE_CLOUDKIT` est defini
/// (configuration Release uniquement, voir project.yml). En Debug, le flag est absent :
/// aucun container iCloud n'est requis pour developper en local.
public enum SlateContainer {
    /// Cree le `ModelContainer` de l'application.
    ///
    /// - Parameters:
    ///   - inMemory: si `true`, force un stockage en memoire (utilise par les tests
    ///     rapides) et desactive CloudKit dans tous les cas, meme si `SLATE_CLOUDKIT`
    ///     est defini.
    ///   - storeURL: emplacement disque explicite du store SwiftData. Reserve aux
    ///     tests qui doivent verifier une persistance reelle entre deux ouvertures de
    ///     container (deux "lancements" successifs sur le meme fichier). `nil` par
    ///     defaut : SwiftData choisit alors son emplacement standard, comportement
    ///     identique a avant l'ajout de ce parametre. Quand `storeURL` est fourni,
    ///     CloudKit est desactive dans tous les cas, meme si `SLATE_CLOUDKIT` est
    ///     defini : un store de test ne doit jamais tenter de se synchroniser.
    public static func make(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SlateSchema.Current.self)

        let configuration: ModelConfiguration
        #if SLATE_CLOUDKIT
        if inMemory || storeURL != nil {
            configuration = Self.configuration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                storeURL: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = Self.configuration(
                schema: schema,
                isStoredInMemoryOnly: false,
                storeURL: nil,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        }
        #else
        configuration = Self.configuration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            storeURL: storeURL,
            cloudKitDatabase: .none
        )
        #endif

        return try ModelContainer(
            for: schema,
            migrationPlan: SlateSchemaMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Construit un `ModelConfiguration`, avec ou sans URL de store explicite.
    ///
    /// SwiftData ne propose pas d'initialiseur `ModelConfiguration` unique couvrant a
    /// la fois `url:` et l'absence d'URL (emplacement par defaut) : on isole donc ce
    /// choix ici pour ne pas dupliquer les branches `#if SLATE_CLOUDKIT` ci-dessus.
    private static func configuration(
        schema: Schema,
        isStoredInMemoryOnly: Bool,
        storeURL: URL?,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) -> ModelConfiguration {
        if let storeURL {
            ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: cloudKitDatabase
            )
        } else {
            ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: isStoredInMemoryOnly,
                cloudKitDatabase: cloudKitDatabase
            )
        }
    }

    /// `true` si CloudKit est actif dans le binaire courant (flag `SLATE_CLOUDKIT`
    /// present a la compilation). Utile pour un affichage de diagnostic dans l'UI.
    public static var isCloudKitEnabled: Bool {
        #if SLATE_CLOUDKIT
        true
        #else
        false
        #endif
    }
}

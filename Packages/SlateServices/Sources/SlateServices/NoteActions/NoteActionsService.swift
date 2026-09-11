import Foundation
import SlateModel
import SwiftData

/// Actions de gestion d'une `Note` façon Notes d'Apple (`docs/11_organisation_notes.md`) :
/// duplication profonde, déplacement, épingle/favori, cycle de corbeille et purge
/// automatique.
///
/// Même style que `AttachmentService` : une struct `Sendable` sans état, les méthodes
/// qui touchent au `ModelContext` sont `@MainActor` (SwiftData n'est pas thread-safe),
/// celles qui ne font que lire/écrire des propriétés scalaires d'un objet déjà en main
/// ne le sont pas nécessairement mais restent `@MainActor` par cohérence et parce que
/// tout accès à un `@Model` doit se faire depuis l'acteur qui possède son
/// `ModelContext` (voir `docs/02_modele_donnees.md`).
public struct NoteActionsService: Sendable {
    /// Durée de rétention en corbeille avant purge automatique, en jours
    /// (`docs/11_organisation_notes.md`, artboard B : "expire dans 28 jours" pour une
    /// note supprimée il y a 2 jours confirme un total de 30 jours).
    public static let trashRetentionDays: Int = 30

    public init() {}

    // MARK: - Duplication profonde

    /// Duplique `note` intégralement : tous ses blocs (récursivement, y compris
    /// colonnes, lignes et cellules de tableau) et leurs pièces jointes. La copie est
    /// insérée dans `context`, dans le même dossier que l'original, avec un titre
    /// suffixé et tous ses identifiants régénérés.
    ///
    /// ## Stratégie retenue : reconstruction récursive, jamais de partage de sous-objet
    ///
    /// Chaque `Block`, `Attachment` de l'original a un équivalent entièrement neuf
    /// (nouvel `id`, nouvelle instance `@Model`) dans la copie. Rien n'est partagé
    /// entre les deux graphes : `RichText`/`BlockAttributes` sont des value types
    /// (`Codable`/`Hashable`, pas des `@Model`), donc les recopier par affectation
    /// suffit déjà à obtenir une copie indépendante (Swift copie la valeur, pas une
    /// référence) ; `Attachment.data` est un `Data` (value type) recopié à l'identique
    /// dans une nouvelle entité `Attachment`. Aucun objet de l'original n'est
    /// réutilisé tel quel dans la copie : modifier l'une des deux notes après coup ne
    /// peut donc jamais atteindre l'autre.
    ///
    /// Régénérer les `id` est impératif : un `id` partagé entre deux `Note`/`Block`
    /// distincts serait une corruption silencieuse (deux enregistrements SwiftData
    /// avec le même identifiant logique), même si SwiftData ne l'empêche pas au
    /// niveau du store.
    ///
    /// `plainText`/`snippetText` sont recalculés via `refreshDerivedText()` une fois
    /// tous les blocs de la copie en place (voir la documentation de `Note` :
    /// c'est le point d'entrée unique de ce recalcul), plutôt que recopiés depuis
    /// l'original : c'est la même donnée dérivée, la calculer à neuf est aussi sûr
    /// et évite de dépendre d'un état potentiellement obsolète de l'original.
    ///
    /// ## Sécurité (Phase 12) : `isLocked` est préservé, jamais forcé à `false`
    ///
    /// Les blocs eux-mêmes ne sont jamais vidés par le verrouillage (voir
    /// `Note.lock()` : seuls `plainText`/`snippetText` le sont) - c'est un choix
    /// assumé, pas un chiffrement. Si la copie d'une note verrouillée démarrait
    /// déverrouillée, elle exposerait donc en clair (extrait, recherche, contenu
    /// ouvert sans authentification) tout le contenu que l'original protégeait,
    /// via un menu contextuel qui n'exige lui-même aucune authentification
    /// (`NoteContextMenuContent` n'a jamais désactivé "Dupliquer" pour une note
    /// verrouillée). Propager `isLocked` maintient la copie derrière le même mot de
    /// passe d'app que l'original, et `refreshDerivedText()` ci-dessous fait alors
    /// respecter l'invariant habituel (champs dérivés vides tant que verrouillée).
    @MainActor
    public func duplicate(_ note: Note, in context: ModelContext, locale: Locale = .current) -> Note {
        let copy = Note(
            title: Self.duplicatedTitle(from: note.title, locale: locale),
            isPinned: false,
            isLocked: note.isLocked,
            isFavorite: false,
            isTrashed: false,
            trashedAt: nil,
            iconName: note.iconName,
            coverImageData: note.coverImageData,
            folder: note.folder
        )
        context.insert(copy)

        let originalRootBlocks = (note.blocks ?? []).sorted { $0.order < $1.order }
        copy.blocks = originalRootBlocks.map { Self.duplicateBlockTree($0, note: copy, parent: nil, in: context) }

        copy.refreshDerivedText()
        return copy
    }

    /// Copie récursive d'un bloc et de tous ses descendants (`children`), en
    /// régénérant chaque `id` et en dupliquant la pièce jointe le cas échéant. Voir la
    /// documentation de `duplicate(_:in:locale:)` pour la stratégie d'ensemble.
    private static func duplicateBlockTree(
        _ original: Block,
        note: Note,
        parent: Block?,
        in context: ModelContext
    ) -> Block {
        let copy = Block(
            order: original.order,
            type: original.type,
            text: original.text,
            attributes: original.attributes,
            note: note,
            parent: parent
        )
        context.insert(copy)

        if let originalAttachment = original.attachment {
            let attachmentCopy = Attachment(
                filename: originalAttachment.filename,
                uti: originalAttachment.uti,
                data: originalAttachment.data,
                width: originalAttachment.width,
                height: originalAttachment.height,
                createdAt: originalAttachment.createdAt,
                block: copy
            )
            context.insert(attachmentCopy)
            copy.attachment = attachmentCopy
        }

        let originalChildren = (original.children ?? []).sorted { $0.order < $1.order }
        copy.children = originalChildren.map { duplicateBlockTree($0, note: note, parent: copy, in: context) }

        return copy
    }

    /// Titre de la copie, suffixé comme dans Notes d'Apple ("Titre copie" en
    /// français, "Title copy" en anglais). Un titre vide reste vide suffixé (juste le
    /// mot "copie"/"copy"), plutôt que de fabriquer un titre par défaut qui
    /// n'existait pas dans l'original.
    private static func duplicatedTitle(from title: String, locale: Locale) -> String {
        let suffix = locale.language.languageCode?.identifier == "fr" ? "copie" : "copy"
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? suffix : "\(trimmed) \(suffix)"
    }

    // MARK: - Déplacement

    /// Déplace `note` vers `folder` (`nil` pour la détacher de tout dossier, cas peu
    /// probable en usage normal mais que le modèle autorise : `Note.folder` est
    /// optionnel).
    @MainActor
    public func move(_ note: Note, to folder: Folder?) {
        note.folder = folder
    }

    // MARK: - Épingle / favori

    @MainActor
    public func setPinned(_ isPinned: Bool, for note: Note) {
        note.isPinned = isPinned
    }

    @MainActor
    public func setFavorite(_ isFavorite: Bool, for note: Note) {
        note.isFavorite = isFavorite
    }

    // MARK: - Corbeille

    /// Met `note` à la corbeille : `isTrashed = true`, `trashedAt` horodaté à `now`.
    @MainActor
    public func moveToTrash(_ note: Note, now: Date = .now) {
        note.isTrashed = true
        note.trashedAt = now
    }

    /// Restaure `note` depuis la corbeille : `isTrashed = false`, `trashedAt` effacé.
    @MainActor
    public func restore(_ note: Note) {
        note.isTrashed = false
        note.trashedAt = nil
    }

    /// Supprime définitivement `note` : purge réelle du `ModelContext` (pas un simple
    /// détachement, voir l'avertissement ci-dessous), ses blocs et pièces jointes
    /// disparaissant par cascade (`deleteRule: .cascade` sur `Note.blocks`,
    /// `Block.children`, `Block.attachment`).
    ///
    /// Point de vigilance hérité des phases 8/9 (`docs/02_modele_donnees.md`) :
    /// détacher un objet du graphe (par ex. `folder.notes.removeAll { ... }`) ne le
    /// supprime PAS du `ModelContext` - seul un `context.delete(...)` explicite,
    /// suivi de la cascade, retire réellement les lignes du store. C'est exactement
    /// ce que fait cette méthode.
    @MainActor
    public func deletePermanently(_ note: Note, in context: ModelContext) {
        context.delete(note)
    }

    /// Nombre de jours restants avant la purge automatique de `note`, ou `nil` si la
    /// note n'est pas en corbeille (`trashedAt == nil`). Peut être négatif si la note
    /// est déjà éligible à la purge mais que celle-ci n'a pas encore tourné (cas
    /// transitoire entre deux lancements) : l'appelant qui affiche ce nombre doit le
    /// borner à `0` pour l'affichage ("expire demain" / "expire dans N jours"), ce
    /// que cette méthode ne fait délibérément pas - elle expose la donnée brute,
    /// l'arrondi d'affichage est une préoccupation de présentation.
    public func daysRemainingBeforePurge(
        for note: Note,
        now: Date = .now,
        retentionDays: Int = NoteActionsService.trashRetentionDays,
        calendar: Calendar = .current
    ) -> Int? {
        guard let trashedAt = note.trashedAt else { return nil }
        let expirationDate = calendar.date(byAdding: .day, value: retentionDays, to: trashedAt) ?? trashedAt
        let startOfToday = calendar.startOfDay(for: now)
        let startOfExpiration = calendar.startOfDay(for: expirationDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiration)
        return components.day ?? 0
    }

    /// Purge définitivement toutes les notes en corbeille depuis strictement plus de
    /// `retentionDays` jours, et retourne le nombre de notes purgées.
    ///
    /// Prédicat volontairement strict et conservateur (voir les tests de bornes) :
    /// une note dont `trashedAt` est `nil` n'est **jamais** purgée (elle n'est même
    /// pas censée exister en pratique - `isTrashed == true` implique normalement
    /// `trashedAt != nil` par construction, voir `moveToTrash`/`restore` - mais cette
    /// fonction ne prend aucun risque sur une donnée qui aurait pu être corrompue par
    /// un chemin non prévu) ; une note non `isTrashed` n'est jamais considérée, même
    /// si elle portait un `trashedAt` résiduel. Le calcul de bornes se fait sur des
    /// `Date` complètes (pas des jours calendaires arrondis) : une note mise à la
    /// corbeille il y a exactement `retentionDays` jours et quelques secondes n'est
    /// pas encore purgée, une note mise à la corbeille il y a `retentionDays` jours et
    /// une seconde de plus l'est. C'est un choix délibéré de simplicité et de
    /// sécurité : arrondir à la journée calendaire risquerait de purger une note plus
    /// tôt que promis par l'affichage "expire dans N jours" selon le fuseau horaire.
    @MainActor
    @discardableResult
    public func purgeExpiredTrash(
        in context: ModelContext,
        now: Date = .now,
        retentionDays: Int = NoteActionsService.trashRetentionDays
    ) throws -> Int {
        let predicate = #Predicate<Note> { $0.isTrashed }
        let candidates = try context.fetch(FetchDescriptor<Note>(predicate: predicate))

        var purgedCount = 0
        for note in candidates {
            guard let trashedAt = note.trashedAt else { continue }
            guard let expirationDate = Calendar.current.date(byAdding: .day, value: retentionDays, to: trashedAt) else {
                continue
            }
            guard expirationDate < now else { continue }
            context.delete(note)
            purgedCount += 1
        }

        if purgedCount > 0 {
            try context.save()
        }
        return purgedCount
    }
}

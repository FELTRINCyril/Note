import Foundation
import SlateModel
import SwiftUI

/// Abstraction legere autour du futur `NoteActionsService` (`SlateServices`, livre en
/// parallele de cette phase par un autre agent - voir `docs/11_organisation_notes.md`).
///
/// Cette phase ne doit NI reimplementer NI stubber en dur la logique metier
/// (duplication profonde, corbeille, purge...) : ce protocole ne fait que decrire le
/// CONTRAT attendu, pour que tout le code UI de la phase (menus contextuels, vue
/// Corbeille) puisse etre ecrit et teste des maintenant, puis branche sur
/// l'implementation reelle en une seule ligne (`environment(\.noteActions, ...)`) une
/// fois `NoteActionsService` livre.
///
/// **A l'attention de l'agent qui branchera le service reel** : faire conformer
/// `SlateServices.NoteActionsService` a ce protocole (ou ecrire un petit adaptateur dans
/// `SlateFeatures` si les signatures reelles different legerement), puis remplacer
/// `UnavailableNoteActionsProvider` par l'instance reelle au point d'injection de
/// l'application (probablement `SlateApp`/`MainWindowView`, hors du perimetre de cet
/// agent). Tant que ce branchement n'est pas fait, toute action de ce protocole est un
/// no-op qui echoue silencieusement en `Release` et declenche un `assertionFailure` en
/// `Debug` (voir `UnavailableNoteActionsProvider` plus bas) - **aucune fenetre n'a ete
/// ouverte dans cette session pour verifier ce comportement au runtime**, seule la
/// forme du contrat est garantie par la compilation/les tests.
///
/// Delibermement absent de ce protocole : le calcul de la date/du nombre de jours
/// d'expiration d'une note en corbeille. C'est une projection PURE de `note.trashedAt`
/// (voir `TrashRetentionPolicy`), calculable et testable des maintenant sans dependre
/// du service - inutile de la faire transiter par cette abstraction.
@MainActor
public protocol NoteActionsProviding: AnyObject {
    /// Duplique chaque note de `notes` (copie profonde : blocs, pieces jointes,
    /// nouveaux identifiants, suffixe "copie"). Retourne les copies creees, dans le
    /// meme ordre que `notes`.
    @discardableResult
    func duplicate(_ notes: [Note]) throws -> [Note]

    /// Deplace toutes les notes de `notes` vers `folder`.
    func move(_ notes: [Note], to folder: Folder) throws

    /// Fixe l'etat d'epinglage de toutes les notes de `notes` a `isPinned`.
    func setPinned(_ isPinned: Bool, for notes: [Note]) throws

    /// Fixe l'etat de favori de toutes les notes de `notes` a `isFavorite`.
    func setFavorite(_ isFavorite: Bool, for notes: [Note]) throws

    /// Met toutes les notes de `notes` a la corbeille (`isTrashed = true`,
    /// `trashedAt` horodate).
    func moveToTrash(_ notes: [Note]) throws

    /// Restaure toutes les notes de `notes` depuis la corbeille.
    func restore(_ notes: [Note]) throws

    /// Supprime definitivement toutes les notes de `notes` (et leurs pieces jointes).
    /// Irreversible - l'appelant est responsable d'avoir deja obtenu confirmation
    /// (voir `DeletePermanentlyAlert`).
    func deletePermanently(_ notes: [Note]) throws

    /// Purge (suppression definitive) toute note en corbeille depuis plus de
    /// `TrashRetentionPolicy.retentionDays` a la date `now`. Retourne le nombre de
    /// notes purgees. A appeler au lancement de l'app (hors perimetre de cet agent :
    /// aucune vue de cette phase ne l'appelle elle-meme).
    @discardableResult
    func purgeExpiredTrash(now: Date) throws -> Int
}

/// Implementation de secours injectee par defaut dans l'environnement : toute action
/// echoue au lieu de faire semblant de reussir, pour ne jamais masquer un oubli de
/// branchement. `assertionFailure` en Debug (crash immediat des les tests UI/preview
/// manuels), no-op silencieux en Release (une app livree ne doit jamais planter sur un
/// defaut de branchement, meme si celui-ci ne devrait jamais arriver en pratique).
public final class UnavailableNoteActionsProvider: NoteActionsProviding {
    public init() {}

    private func fail(_ function: StaticString = #function) throws {
        assertionFailure(
            "NoteActionsProviding.\(function) appele sans service reel branche (voir NoteActionsProviding.swift)"
        )
        throw NoteActionsUnavailableError()
    }

    public func duplicate(_ notes: [Note]) throws -> [Note] {
        try fail()
        return []
    }

    public func move(_ notes: [Note], to folder: Folder) throws {
        try fail()
    }

    public func setPinned(_ isPinned: Bool, for notes: [Note]) throws {
        try fail()
    }

    public func setFavorite(_ isFavorite: Bool, for notes: [Note]) throws {
        try fail()
    }

    public func moveToTrash(_ notes: [Note]) throws {
        try fail()
    }

    public func restore(_ notes: [Note]) throws {
        try fail()
    }

    public func deletePermanently(_ notes: [Note]) throws {
        try fail()
    }

    public func purgeExpiredTrash(now: Date) throws -> Int {
        try fail()
        return 0
    }
}

/// Erreur levee par `UnavailableNoteActionsProvider` : le service reel n'est pas
/// encore branche dans l'environnement.
public struct NoteActionsUnavailableError: Error {
    public init() {}
}

/// Injection de `NoteActionsProviding` dans l'environnement SwiftUI, meme motif que
/// `AppState` (`AppState.swift`).
@MainActor
private struct NoteActionsKey: @MainActor EnvironmentKey {
    static let defaultValue: NoteActionsProviding = UnavailableNoteActionsProvider()
}

extension EnvironmentValues {
    /// Acces au service d'actions de note depuis n'importe quelle vue :
    /// `@Environment(\.noteActions) private var noteActions`.
    @MainActor
    public var noteActions: NoteActionsProviding {
        get { self[NoteActionsKey.self] }
        set { self[NoteActionsKey.self] = newValue }
    }
}

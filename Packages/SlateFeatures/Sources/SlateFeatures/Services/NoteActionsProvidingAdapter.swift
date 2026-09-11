import Foundation
import SlateModel
import SlateServices
import SwiftData

/// Adapte l'API par-note de `SlateServices.NoteActionsService` (livree en parallele de
/// cette phase, voir la mise en garde de `NoteActionsProviding.swift`) au contrat par
/// LOT (`[Note]`) attendu par les vues de cette phase (menus contextuels en selection
/// multiple, `TrashView`).
///
/// **Point de branchement REEL** : injecte par `MainWindowView`, remplace
/// `UnavailableNoteActionsProvider` (valeur par defaut de l'environnement) des que le
/// contexte de modele est disponible. La mise en garde documentee sur
/// `UnavailableNoteActionsProvider` ("aucun service reel branche") ne s'applique donc
/// plus a l'app assemblee - seuls les previews/tests qui ne passent pas par
/// `MainWindowView` restent sur le defaut inerte.
@MainActor
final class NoteActionsProvidingAdapter: NoteActionsProviding {
    private let service = NoteActionsService()
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func duplicate(_ notes: [Note]) throws -> [Note] {
        let copies = notes.map { service.duplicate($0, in: modelContext) }
        try modelContext.save()
        return copies
    }

    func move(_ notes: [Note], to folder: Folder) throws {
        notes.forEach { service.move($0, to: folder) }
        try modelContext.save()
    }

    func setPinned(_ isPinned: Bool, for notes: [Note]) throws {
        notes.forEach { service.setPinned(isPinned, for: $0) }
        try modelContext.save()
    }

    func setFavorite(_ isFavorite: Bool, for notes: [Note]) throws {
        notes.forEach { service.setFavorite(isFavorite, for: $0) }
        try modelContext.save()
    }

    func moveToTrash(_ notes: [Note]) throws {
        notes.forEach { service.moveToTrash($0) }
        try modelContext.save()
    }

    func restore(_ notes: [Note]) throws {
        notes.forEach { service.restore($0) }
        try modelContext.save()
    }

    func deletePermanently(_ notes: [Note]) throws {
        notes.forEach { service.deletePermanently($0, in: modelContext) }
        try modelContext.save()
    }

    @discardableResult
    func purgeExpiredTrash(now: Date) throws -> Int {
        try service.purgeExpiredTrash(in: modelContext, now: now)
    }
}

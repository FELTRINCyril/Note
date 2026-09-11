import AppKit
import SwiftUI
import SlateModel

/// Selection multiple, menu contextuel et actions de note de `NoteListView` (design
/// P3, artboard A). Extrait dans son propre fichier pour tenir la limite `file_length`
/// de SwiftLint (`NoteListView.swift` gere deja l'essentiel de la spec E3).
///
/// Toutes les mutations passent par `noteActions` (`NoteActionsProviding`), jamais par
/// un acces direct a `modelContext` : ce sera le SEUL point de branchement du vrai
/// `NoteActionsService` (`SlateServices`) une fois livre - voir `NoteActionsProviding.swift`.
extension NoteListView {
    // MARK: - Selection

    func isCellSelected(_ note: Note) -> Bool {
        if !selectedNoteIDs.isEmpty {
            return selectedNoteIDs.contains(note.id)
        }
        return appState.selectedNote?.id == note.id
    }

    /// Gere Cmd-clic (bascule dans la selection), Maj-clic (extension de plage depuis
    /// `shiftAnchorID`) et clic simple (remplace la selection). `NSEvent.modifierFlags`
    /// est la seule facon d'obtenir les modificateurs clavier d'un `onTapGesture`
    /// SwiftUI sur macOS (pas d'API SwiftUI dediee pour ce geste precis).
    func handleCellTap(_ note: Note, in allNotes: [Note]) {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.command) {
            toggleInSelection(note)
        } else if modifiers.contains(.shift), let anchorID = shiftAnchorID,
            let anchorIndex = allNotes.firstIndex(where: { $0.id == anchorID }),
            let clickedIndex = allNotes.firstIndex(where: { $0.id == note.id }) {
            let range = anchorIndex < clickedIndex ? anchorIndex...clickedIndex : clickedIndex...anchorIndex
            selectedNoteIDs = Set(allNotes[range].map(\.id))
            appState.selectedNote = note
        } else {
            selectedNoteIDs = []
            shiftAnchorID = note.id
            appState.selectedNote = note
        }
        focusedNoteID = note.id
    }

    private func toggleInSelection(_ note: Note) {
        // Amorce la selection multiple a partir du clic simple courant si aucune
        // n'existe encore (Cmd-clic sur une deuxieme cellule sans Cmd-clic prealable
        // sur la premiere doit quand meme produire une selection de deux).
        if selectedNoteIDs.isEmpty, let current = appState.selectedNote {
            selectedNoteIDs = [current.id]
        }
        if selectedNoteIDs.contains(note.id) {
            selectedNoteIDs.remove(note.id)
        } else {
            selectedNoteIDs.insert(note.id)
        }
        shiftAnchorID = note.id
        if selectedNoteIDs.count == 1, let onlyID = selectedNoteIDs.first,
            let onlyNote = noteMatching(onlyID, in: [note]) {
            appState.selectedNote = onlyNote
        }
    }

    private func noteMatching(_ id: Note.ID, in notes: [Note]) -> Note? {
        notes.first { $0.id == id }
    }

    /// Notes visees par une action de menu contextuel invoquee en cliquant sur `note` :
    /// la selection multiple courante si `note` en fait partie, sinon seulement `note`
    /// (clic droit "hors selection" = action sur cette seule cellule, comportement de
    /// Notes/Finder).
    func selectionForContextMenu(clicking note: Note, in allNotes: [Note] = []) -> [Note] {
        guard selectedNoteIDs.contains(note.id), selectedNoteIDs.count > 1 else { return [note] }
        // `allNotes` n'est pas force parametre ici : le menu contextuel est construit
        // depuis `cellRow`, qui connait deja la liste visible complete au moment de
        // l'appel (voir son usage dans `NoteListView.swift`). Reconstitue depuis
        // `navigationOrder` si jamais un appelant ne la fournit pas.
        let pool = allNotes.isEmpty ? navigationOrder : allNotes
        return pool.filter { selectedNoteIDs.contains($0.id) }
    }

    // MARK: - Dossiers candidats pour "Deplacer vers"

    var candidateFoldersForMove: [Folder] {
        guard let workspace = appState.selectedWorkspace else { return [] }
        return allFolders
            .filter { $0.space?.workspace?.id == workspace.id }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Actions

    func toggleSelectionPin(clicking note: Note) {
        performPin(on: selectionForContextMenu(clicking: note))
    }

    /// Critere d'acceptation `docs/11_organisation_notes.md` : la bascule doit
    /// remonter IMMEDIATEMENT dans la section Favoris de la sidebar (`SidebarView`,
    /// `@Query(filter: #Predicate<Note> { $0.isFavorite && !$0.isTrashed })`) - garanti
    /// par SwiftData des que `note.isFavorite` change sur un objet du meme
    /// `ModelContext`, sans action supplementaire de cette vue.
    func toggleSelectionFavorite(clicking note: Note) {
        let selection = selectionForContextMenu(clicking: note)
        let shouldFavorite = !selection.allSatisfy(\.isFavorite)
        try? noteActions.setFavorite(shouldFavorite, for: selection)
    }

    /// "Verrouiller la note" (Phase 12, `docs/12_verrouillage.md`). Si aucun mot de
    /// passe d'app n'est encore defini, propose D'ABORD de le definir (feuille
    /// `SetPasswordSheet`) et memorise la selection pour la verrouiller une fois la
    /// definition validee (`lockPendingSelection`) -- jamais de verrouillage silencieux
    /// sans mot de passe utilisable pour deverrouiller ensuite.
    func lockSelection(clicking note: Note) {
        performLock(on: selectionForContextMenu(clicking: note))
    }

    /// Verrouille la selection memorisee par `lockSelection(clicking:)` une fois le mot
    /// de passe d'app defini avec succes (voir le `.sheet` de `NoteListView`).
    func lockPendingSelection() {
        for target in pendingLockSelection {
            lockService.lock(target)
        }
        pendingLockSelection = []
    }

    func duplicateSelection(clicking note: Note) {
        performDuplicate(on: selectionForContextMenu(clicking: note))
    }

    func moveSelection(clicking note: Note, to folder: Folder) {
        let selection = selectionForContextMenu(clicking: note)
        try? noteActions.move(selection, to: folder)
    }

    func presentNewFolderForMove(clicking note: Note) {
        guard let space = appState.selectedFolder?.space else { return }
        pendingMoveSelection = selectionForContextMenu(clicking: note)
        newFolderPromptContext = FolderNamePromptContext(mode: .newSubfolder(parent: nil, space: space))
    }

    func submitNewFolderForMove(context: FolderNamePromptContext, name: String) {
        guard case .newSubfolder(_, let space) = context.mode else { return }
        let navigation = SidebarNavigation(context: modelContext)
        guard let folder = try? navigation.createFolder(named: name, in: space) else { return }
        try? noteActions.move(pendingMoveSelection, to: folder)
        pendingMoveSelection = []
    }

    /// "Copier le lien interne" : desactive par `NoteContextMenuContent` des que la
    /// selection contient plus d'une note, `note` est donc toujours la seule cible ici.
    func copyInternalLink(for note: Note) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(NoteInternalLink.url(for: note).absoluteString, forType: .string)
    }

    func trashSelection(clicking note: Note) {
        performTrash(on: selectionForContextMenu(clicking: note))
    }
}

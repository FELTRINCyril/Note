import SwiftUI
import SlateModel

/// Pont entre les actions de note et les commandes globales de la barre de menu
/// (Phase 14, `docs/14_raccourcis_clavier.md`, `SlateAppCommands`). Porte aussi la
/// logique PARTAGEE avec le menu contextuel (`NoteListView+ContextMenuActions.swift`) :
/// les deux operent sur un tableau `[Note]` deja resolu, seule la facon de calculer
/// cette selection differe (clic droit sur une cellule contre "selection courante" sans
/// aucun clic d'origine, necessaire pour une commande de menu bar).
///
/// Corrige le manque documente dans `STATUT.md` : Ctrl+Cmd+P (epingler), Cmd+D
/// (dupliquer), Ctrl+Cmd+L (verrouiller) et Cmd+Retour arriere (corbeille) n'etaient
/// actifs QUE menu contextuel deja ouvert.
extension NoteListView {
    /// Notes visees par une commande de menu bar : la selection multiple courante si
    /// elle existe, sinon la note unique affichee dans la colonne detail. Vide si
    /// aucune note n'est selectionnee -- voir `noteMenuCommandActions` pour la
    /// desactivation qui en decoule.
    var currentMenuSelection: [Note] {
        guard selectedNoteIDs.isEmpty else {
            return navigationOrder.filter { selectedNoteIDs.contains($0.id) }
        }
        return appState.selectedNote.map { [$0] } ?? []
    }

    /// Valeur publiee pour `SlateAppCommands` (voir `SlateFocusedValues.swift`). `nil`
    /// des que la selection est vide : la commande se desactive plutot que d'agir sur
    /// une liste vide.
    var noteMenuCommandActions: NoteMenuCommandActions? {
        let selection = currentMenuSelection
        guard !selection.isEmpty else { return nil }
        return NoteMenuCommandActions(
            pinTitle: pinTitle(for: selection),
            togglePin: { performPin(on: selection) },
            duplicateTitle: NoteSelectionActionLabels.duplicate(count: selection.count),
            duplicate: { performDuplicate(on: selection) },
            isLockDisabled: NoteContextMenuContent.isLockDisabled(for: selection),
            lock: { performLock(on: selection) },
            trashTitle: NoteSelectionActionLabels.moveToTrash(count: selection.count),
            trash: { performTrash(on: selection) }
        )
    }

    private func pinTitle(for selection: [Note]) -> String {
        let isAllPinned = !selection.isEmpty && selection.allSatisfy(\.isPinned)
        return isAllPinned
            ? String(localized: "noteList.contextMenu.unpin", bundle: .module)
            : String(localized: "noteList.contextMenu.pin", bundle: .module)
    }

    // MARK: - Actions partagees avec le menu contextuel

    func performPin(on selection: [Note]) {
        let shouldPin = !selection.allSatisfy(\.isPinned)
        try? noteActions.setPinned(shouldPin, for: selection)
    }

    func performDuplicate(on selection: [Note]) {
        _ = try? noteActions.duplicate(selection)
    }

    /// Meme regle que l'ancien `lockSelection(clicking:)` : si aucun mot de passe
    /// d'app n'est encore defini, propose D'ABORD de le definir (voir le `.sheet` de
    /// `NoteListView`) et memorise la selection pour la verrouiller une fois la
    /// definition validee.
    func performLock(on selection: [Note]) {
        guard lockService.isPasswordSet else {
            pendingLockSelection = selection
            isSetPasswordSheetPresented = true
            return
        }
        for target in selection {
            lockService.lock(target)
        }
    }

    func performTrash(on selection: [Note]) {
        try? noteActions.moveToTrash(selection)
        if selection.contains(where: { $0.id == appState.selectedNote?.id }) {
            appState.selectedNote = nil
        }
        selectedNoteIDs.subtract(selection.map(\.id))
    }
}

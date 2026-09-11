import SwiftUI
import SlateModel

/// Contenu du menu contextuel de note (design P3, artboard A), partage entre clic
/// droit sur une seule cellule et selection multiple - seuls les libelles changent
/// (comptes, voir `NoteSelectionActionLabels`), jamais la liste d'actions presentes :
/// "les actions impossibles sur l'ensemble sont desactivees, pas masquees" (design P3).
///
/// "Ajouter/Retirer des favoris" n'apparait PAS dans la maquette A (qui n'est qu'un
/// exemple de menu, pas une liste exhaustive), mais c'est un critere d'acceptation
/// explicite de `docs/11_organisation_notes.md` : sans cette entree, la section
/// Favoris de la sidebar (Phase 3) resterait impossible a remplir depuis l'UI. Meme
/// grammaire visuelle que "Epingler" (bascule sur l'etat dominant de la selection,
/// voir `isAllFavorite`).
///
/// Deux entrees restent volontairement INERTES dans cette phase, chacune documentee a
/// l'appel :
/// - "Verrouiller" : la Phase 12 (verrouillage) n'est pas encore implementee. L'entree
///   est presente (le raccourci ⌃⌘L existe deja dans la maquette) mais desactivee.
/// - "Exporter..." : aucun mecanisme d'export n'existe dans le code a ce jour (aucune
///   phase dediee, aucun format defini). Ecart assume, a signaler explicitement plutot
///   que d'inventer un format d'export non specifie.
struct NoteContextMenuContent: View {
    let selection: [Note]
    /// Dossiers candidats pour "Deplacer vers" (design : liste plate du workspace
    /// courant). Le dossier porteur de la note (selection a une seule note) reste dans
    /// la liste, coche, comme dans la maquette ("Produit" surligne).
    let candidateFolders: [Folder]

    let onTogglePin: () -> Void
    let onToggleFavorite: () -> Void
    let onDuplicate: () -> Void
    let onMove: (Folder) -> Void
    let onRequestNewFolder: () -> Void
    let onCopyInternalLink: () -> Void
    let onMoveToTrash: () -> Void

    private var count: Int { selection.count }
    private var isMultiple: Bool { count > 1 }

    private var isAllPinned: Bool {
        !selection.isEmpty && selection.allSatisfy(\.isPinned)
    }

    /// Critere d'acceptation `docs/11_organisation_notes.md` : "Deplacer / epingler /
    /// favori mettent a jour sidebar et liste immediatement" - sans cette entree, la
    /// section Favoris de la sidebar (Phase 3) ne serait jamais alimentable. Meme
    /// grammaire que `isAllPinned`/`onTogglePin` : bascule sur l'etat DOMINANT de la
    /// selection (tout mettre en favori des qu'au moins une note ne l'est pas encore).
    private var isAllFavorite: Bool {
        !selection.isEmpty && selection.allSatisfy(\.isFavorite)
    }

    var body: some View {
        if isMultiple {
            Text(NoteSelectionActionLabels.selectionHeader(count: count))
        }

        Button(action: onTogglePin) {
            Label(pinLabel, systemImage: isAllPinned ? "pin.slash" : "pin")
        }
        .keyboardShortcut("p", modifiers: [.control, .command])

        Button(action: onToggleFavorite) {
            Label(favoriteLabel, systemImage: isAllFavorite ? "star.slash" : "star")
        }

        Button {
        } label: {
            Label(String(localized: "noteList.contextMenu.lock", bundle: .module), systemImage: "lock")
        }
        .keyboardShortcut("l", modifiers: [.control, .command])
        .disabled(true)

        Button(action: onDuplicate) {
            Label(NoteSelectionActionLabels.duplicate(count: count), systemImage: "doc.on.doc")
        }
        .keyboardShortcut("d", modifiers: .command)

        Menu {
            ForEach(candidateFolders) { folder in
                Button {
                    onMove(folder)
                } label: {
                    if isCurrentFolder(folder) {
                        Label(folder.name, systemImage: "checkmark")
                    } else {
                        Text(folder.name)
                    }
                }
            }
            if !candidateFolders.isEmpty {
                Divider()
            }
            Button(action: onRequestNewFolder) {
                Label(String(localized: "noteList.contextMenu.newFolder", bundle: .module), systemImage: "plus")
            }
        } label: {
            Label(String(localized: "noteList.contextMenu.moveTo", bundle: .module), systemImage: "folder")
        }

        Divider()

        Button {
        } label: {
            Label(String(localized: "noteList.contextMenu.export", bundle: .module), systemImage: "square.and.arrow.up")
        }
        .disabled(true)

        Button(action: onCopyInternalLink) {
            Label(String(localized: "noteList.contextMenu.copyLink", bundle: .module), systemImage: "link")
        }
        .disabled(count != 1)

        Divider()

        Button(role: .destructive, action: onMoveToTrash) {
            Label(NoteSelectionActionLabels.moveToTrash(count: count), systemImage: "trash")
        }
        .keyboardShortcut(.delete, modifiers: .command)
    }

    private var pinLabel: String {
        isAllPinned
            ? String(localized: "noteList.contextMenu.unpin", bundle: .module)
            : String(localized: "noteList.contextMenu.pin", bundle: .module)
    }

    private var favoriteLabel: String {
        isAllFavorite
            ? NoteSelectionActionLabels.removeFavorite(count: count)
            : NoteSelectionActionLabels.addFavorite(count: count)
    }

    private func isCurrentFolder(_ folder: Folder) -> Bool {
        count == 1 && selection.first?.folder?.id == folder.id
    }
}

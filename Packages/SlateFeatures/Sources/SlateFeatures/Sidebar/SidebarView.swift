import SwiftUI
import SwiftData
import SlateModel
import SlateUI

/// Barre laterale de l'app (`docs/03_sidebar_navigation.md`) : selecteur de
/// workspace, favoris, arbre recursif de sections/dossiers, pied d'actions.
///
/// Un seul `@Query` porte l'integralite des dossiers (spec : "alimentee par @Query
/// sur Space/Folder") ; chaque `FolderRow` filtre ce meme tableau pour ses propres
/// enfants plutot que de re-interroger SwiftData a chaque niveau de recursion (voir
/// la documentation de `FolderRow`).
public struct SidebarView: View {
    @Environment(\.appState) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings

    @Query(sort: [SortDescriptor(\Space.sortIndex), SortDescriptor(\Space.name)])
    private var allSpaces: [Space]

    @Query(sort: [SortDescriptor(\Folder.sortIndex), SortDescriptor(\Folder.name)])
    private var allFolders: [Folder]

    @Query(filter: #Predicate<Note> { $0.isFavorite && !$0.isTrashed }, sort: [SortDescriptor(\Note.title)])
    private var allFavoriteNotes: [Note]

    @FocusState private var focusedFolderID: Folder.ID?

    @State private var namePromptContext: FolderNamePromptContext?
    @State private var iconPickerTarget: Folder?
    @State private var deletionCandidate: Folder?
    @State private var showsNewSpaceComingSoonAlert = false
    @State private var showsTrash = false

    /// Focus de panneau PARTAGE avec `MainWindowView` (Phase 14, ⌃⌘1) -- voir
    /// `SlatePanelFocus`. Distinct de `focusedFolderID` ci-dessus (qui reste le SEUL
    /// proprietaire du focus PAR LIGNE) : ce binding ne fait que donner le focus
    /// clavier reel a la `ScrollView` ci-dessous, qui porte deja les `onKeyPress`
    /// haut/bas/gauche/droite -- la toute premiere fleche pressee ensuite delegue
    /// normalement a `handleVerticalArrow(_:)`, qui focalise alors la ligne concernee
    /// via `focusedFolderID` exactement comme un clic l'aurait fait.
    let panelFocus: FocusState<SlatePanelFocus?>.Binding

    public init(panelFocus: FocusState<SlatePanelFocus?>.Binding) {
        self.panelFocus = panelFocus
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    WorkspaceSwitcherRow(workspace: appState.selectedWorkspace)

                    if !favoriteNotes.isEmpty {
                        SidebarSectionHeader(String(localized: "sidebar.section.favorites", bundle: .module))
                        ForEach(favoriteNotes) { note in
                            FavoriteNoteRow(note: note)
                        }
                    }

                    SidebarSectionHeader(
                        String(localized: "sidebar.section.spaces", bundle: .module),
                        action: SidebarSectionHeaderAction(
                            systemImage: "plus",
                            accessibilityLabel: String(localized: "sidebar.action.newSpace", bundle: .module)
                        ) {
                            Task { @MainActor in
                                showsNewSpaceComingSoonAlert = true
                            }
                        }
                    )

                    ForEach(spaces) { space in
                        ForEach(rootFolders(in: space)) { folder in
                            FolderRow(
                                entry: SidebarFolderEntry(folder: folder, indentLevel: 0),
                                allFolders: allFolders,
                                focusedFolderID: $focusedFolderID,
                                onRequestNewSubfolder: { presentNewSubfolderPrompt(parent: $0) },
                                onRequestRename: {
                                    namePromptContext = FolderNamePromptContext(mode: .rename(folder: $0))
                                },
                                onRequestChangeIcon: { iconPickerTarget = $0 },
                                onRequestDelete: { deletionCandidate = $0 }
                            )
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
            .onKeyPress(.upArrow) { handleVerticalArrow(-1) }
            .onKeyPress(.downArrow) { handleVerticalArrow(1) }
            .onKeyPress(.leftArrow) { handleLeftArrow() }
            .onKeyPress(.rightArrow) { handleRightArrow() }
            // Phase 14 (⌃⌘1) : cible du focus de panneau -- voir la documentation de
            // `panelFocus`. `.focusable()` est necessaire pour que cette `ScrollView`
            // (jusqu'ici focalisable seulement INDIRECTEMENT via une ligne de dossier)
            // puisse elle-meme devenir la cible directe d'un `@FocusState`.
            .focusable()
            .focused(panelFocus, equals: .sidebar)

            SidebarFooterView(
                canCreateNote: appState.selectedFolder != nil,
                onOpenSettings: { openSettings() },
                onOpenTrash: { showsTrash = true },
                onNewFolder: createNewFolder,
                onNewNote: createNewNote
            )
        }
        .slateSidebarBackground()
        .sheet(isPresented: $showsTrash) {
            TrashView()
        }
        .sheet(item: $namePromptContext) { context in
            FolderNamePromptSheet(context: context) { name in
                submitNamePrompt(context: context, name: name)
            }
        }
        .sheet(item: $iconPickerTarget) { folder in
            FolderIconPickerSheet(folder: folder) { icon in
                folder.iconName = icon
                try? modelContext.save()
            }
        }
        .confirmationDialog(
            deletionDialogTitle,
            isPresented: Binding(
                get: { deletionCandidate != nil },
                set: { isPresented in if !isPresented { deletionCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "sidebar.folder.delete.confirm", bundle: .module), role: .destructive) {
                if let folder = deletionCandidate {
                    deleteFolder(folder)
                }
                deletionCandidate = nil
            }
            Button(String(localized: "action.cancel", bundle: .module), role: .cancel) {
                deletionCandidate = nil
            }
        } message: {
            Text(String(localized: "sidebar.folder.delete.message", bundle: .module))
        }
        .alert(
            String(localized: "sidebar.action.newSpace.comingSoon.title", bundle: .module),
            isPresented: $showsNewSpaceComingSoonAlert
        ) {
            Button(String(localized: "action.ok", bundle: .module), role: .cancel) {}
        } message: {
            Text(String(localized: "sidebar.action.newSpace.comingSoon.message", bundle: .module))
        }
        // Phase 14 : publie "Nouvelle note"/"Nouveau dossier" pour `SlateAppCommands`
        // (barre de menu Fichier), meme garde que `SidebarFooterView.canCreateNote`.
        .focusedSceneValue(\.newNoteAction, newNoteActionForCommands)
        .focusedSceneValue(\.newFolderAction, { createNewFolder() })
    }

    // MARK: - Donnees derivees

    private var deletionDialogTitle: String {
        guard let folder = deletionCandidate else { return "" }
        let template = String(localized: "sidebar.folder.delete.title", bundle: .module)
        return String(format: template, folder.name)
    }

    private var spaces: [Space] {
        guard let workspace = appState.selectedWorkspace else { return [] }
        return allSpaces.filter { $0.workspace?.id == workspace.id }
    }

    private var favoriteNotes: [Note] {
        guard let workspace = appState.selectedWorkspace else { return [] }
        return allFavoriteNotes.filter { $0.folder?.space?.workspace?.id == workspace.id }
    }

    private func rootFolders(in space: Space) -> [Folder] {
        allFolders.filter { $0.space?.id == space.id && $0.parent == nil }.sorted(by: Folder.sidebarOrder)
    }

    private func subfolders(of folder: Folder) -> [Folder] {
        allFolders.filter { $0.parent?.id == folder.id }.sorted(by: Folder.sidebarOrder)
    }

    /// Ordre visuel aplati de l'arbre de dossiers, toutes sections confondues, utilise
    /// uniquement pour la navigation clavier haut/bas (pas pour le rendu, assure par
    /// la recursion de `FolderRow` - voir `SidebarTreeFlattener`).
    private var flattenedFolders: [SidebarFolderEntry] {
        spaces.flatMap { space in
            SidebarTreeFlattener.flatten(rootFolders: rootFolders(in: space)) { subfolders(of: $0) }
        }
    }

    // MARK: - Navigation clavier

    private func handleVerticalArrow(_ delta: Int) -> KeyPress.Result {
        let order = flattenedFolders
        guard !order.isEmpty else { return .ignored }

        guard let currentID = focusedFolderID, let index = order.firstIndex(where: { $0.folder.id == currentID }) else {
            let first = order[0].folder
            focusedFolderID = first.id
            appState.selectedFolder = first
            return .handled
        }

        let newIndex = index + delta
        guard order.indices.contains(newIndex) else { return .handled }
        let target = order[newIndex].folder
        focusedFolderID = target.id
        appState.selectedFolder = target
        return .handled
    }

    private func handleRightArrow() -> KeyPress.Result {
        guard let id = focusedFolderID, let folder = allFolders.first(where: { $0.id == id }) else { return .ignored }
        let children = subfolders(of: folder)
        guard !children.isEmpty else { return .ignored }
        if !folder.isExpanded {
            folder.isExpanded = true
            try? modelContext.save()
        } else if let firstChild = children.first {
            focusedFolderID = firstChild.id
        }
        return .handled
    }

    private func handleLeftArrow() -> KeyPress.Result {
        guard let id = focusedFolderID, let folder = allFolders.first(where: { $0.id == id }) else { return .ignored }
        if folder.isExpanded && !subfolders(of: folder).isEmpty {
            folder.isExpanded = false
            try? modelContext.save()
        } else if let parent = folder.parent {
            focusedFolderID = parent.id
        } else {
            return .ignored
        }
        return .handled
    }

    // MARK: - Actions

    private func presentNewSubfolderPrompt(parent: Folder) {
        guard let space = parent.space else { return }
        namePromptContext = FolderNamePromptContext(mode: .newSubfolder(parent: parent, space: space))
    }

    private func createNewFolder() {
        if let selected = appState.selectedFolder, let space = selected.space {
            namePromptContext = FolderNamePromptContext(mode: .newSubfolder(parent: selected, space: space))
        } else if let space = spaces.first {
            namePromptContext = FolderNamePromptContext(mode: .newSubfolder(parent: nil, space: space))
        }
    }

    /// Publie via `.focusedSceneValue(\.newNoteAction, ...)` ci-dessus (voir la
    /// documentation de `SlateFocusedValues.newNoteAction`) : `nil` explicitement typé
    /// pour eviter toute ambiguite du compilateur entre une reference de methode et
    /// `nil` dans un operateur ternaire.
    private var newNoteActionForCommands: (() -> Void)? {
        guard appState.selectedFolder != nil else { return nil }
        return { createNewNote() }
    }

    private func createNewNote() {
        guard let folder = appState.selectedFolder else { return }
        let navigation = SidebarNavigation(context: modelContext)
        let title = String(localized: "sidebar.newNote.defaultTitle", bundle: .module)
        appState.selectedNote = try? navigation.createNote(titled: title, in: folder)
    }

    private func submitNamePrompt(context: FolderNamePromptContext, name: String) {
        let navigation = SidebarNavigation(context: modelContext)
        switch context.mode {
        case .newSubfolder(let parent, let space):
            _ = try? navigation.createFolder(named: name, in: space, parent: parent)
        case .rename(let folder):
            try? navigation.rename(folder, to: name)
        }
    }

    /// Nettoie toute reference pendante AVANT de supprimer effectivement le dossier :
    /// `Folder.subfolders`/`Folder.notes` sont en cascade (`Folder.swift`), donc
    /// supprimer un dossier peut supprimer, en une seule fois, un sous-dossier
    /// selectionne (a n'importe quelle profondeur, pas seulement en enfant direct) et
    /// la note affichee dans la colonne du milieu. Toute la logique de "qui est
    /// affecte" est calculee par `FolderDeletionCleanup.plan` (pure, testee) a partir
    /// des objets encore valides, avant l'appel a `navigation.delete` - lire une
    /// propriete d'un objet SwiftData deja supprime n'est pas garanti.
    private func deleteFolder(_ folder: Folder) {
        let navigation = SidebarNavigation(context: modelContext)
        let focusedFolder = focusedFolderID.flatMap { id in allFolders.first { $0.id == id } }

        let plan = FolderDeletionCleanup.plan(
            deleting: folder,
            selectedFolder: appState.selectedFolder,
            selectedNote: appState.selectedNote,
            focusedFolder: focusedFolder
        )

        if plan.clearsSelectedFolder {
            appState.selectedFolder = nil
        }
        if plan.clearsSelectedNote {
            appState.selectedNote = nil
        }
        if plan.clearsFocusedFolder {
            focusedFolderID = nil
        }

        try? navigation.delete(folder)
    }
}

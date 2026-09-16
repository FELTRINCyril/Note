import AppKit
import SwiftUI
import SwiftData
import SlateModel
import SlateUI

/// Colonne du milieu de la coquille (`docs/04_liste_notes.md`, spec E3) : liste des
/// notes du dossier selectionne, avec section "Epinglees" toujours en tete, puis
/// regroupement temporel (`NoteDateGrouper`) ou liste aplatie en tri par titre,
/// recherche et menu de tri.
///
/// ## Pourquoi pas de `#Preview` sur cette vue elle-meme
///
/// Cette vue lit `AppState` (`@Environment(\.appState)`) et `ModelContext`
/// (`@Environment(\.modelContext)`) directement plutot que de recevoir ses donnees en
/// parametres - c'est le meme choix que `SidebarView`/`MainWindowView` (aucune des
/// deux n'a de `#Preview` non plus), qui ont deja tranche que les vues d'assemblage
/// alimentees par `AppState` + SwiftData en direct ne se previsualisent pas seules
/// (il faudrait un `ModelContainer` complet, un `AppState` injecte, ET des donnees de
/// demonstration deja inserees - un cout disproportionne par rapport a une vue de
/// composition qui ne fait qu'assembler des sous-vues DEJA previsualisees
/// individuellement : `NoteCell`, `NoteListSortMenu`, `NoteListEmptyStateView`, et les
/// primitives `SlateUI` sous-jacentes couvrent deja tous les etats visuels requis,
/// clair et sombre compris).
public struct NoteListView: View {
    // Non `private` : accedes depuis `NoteListView+ContextMenuActions.swift` (meme
    // module, extension separee pour tenir la limite `file_length` de SwiftLint).
    @Environment(\.appState) var appState
    @Environment(\.modelContext) var modelContext
    @Environment(\.noteActions) var noteActions
    @Environment(\.lockService) var lockService

    @Query(sort: [SortDescriptor(\Folder.sortIndex), SortDescriptor(\Folder.name)])
    var allFolders: [Folder]

    @State private var searchText = ""
    // Non `private` : lu depuis `NoteListView+DataResolution.swift` (meme module, extension
    // separee pour tenir la limite `file_length` de SwiftLint).
    @State var sortCriterion: NoteSortCriterion = .modifiedDate
    // Non `private` : lu depuis `NoteListView+DataResolution.swift` (meme module, extension
    // separee pour tenir la limite `file_length` de SwiftLint).
    @State var sortDirection: SortDirection = .descending
    @FocusState var focusedNoteID: Note.ID?

    /// Selection multiple (design P3, artboard A) : vide en usage courant (une seule
    /// note "selectionnee" reste pilotee par `appState.selectedNote`, seule source de
    /// verite lue par les AUTRES vues - colonne detail, sidebar...). Non vide des que
    /// l'utilisateur Cmd/Maj-clique plus d'une cellule : dans ce cas, c'est CET etat qui
    /// pilote le surlignage de la liste et le contenu du menu contextuel
    /// (`NoteContextMenuContent`), voir `isCellSelected(_:)`/`selectionForContextMenu(clicking:in:)`.
    @State var selectedNoteIDs: Set<Note.ID> = []

    /// Ancre de la selection par extension (Maj-clic), voir `handleCellTap(_:in:)`.
    @State var shiftAnchorID: Note.ID?

    /// Notes en attente de deplacement une fois le dossier cree via
    /// `newFolderPromptContext` (sous-menu "Deplacer vers" > "Nouveau dossier...").
    @State var pendingMoveSelection: [Note] = []
    @State var newFolderPromptContext: FolderNamePromptContext?

    /// Selection en attente de verrouillage tant qu'aucun mot de passe d'app n'est
    /// encore defini (`lockSelection(clicking:)`) : verrouiller une note sans mot de
    /// passe defini propose D'ABORD d'en definir un (voir `docs/12_verrouillage.md`),
    /// puis verrouille cette selection une fois la definition validee.
    @State var pendingLockSelection: [Note] = []
    @State var isSetPasswordSheetPresented = false

    /// Focus de panneau PARTAGE avec `MainWindowView` (Phase 14, ⌃⌘2) -- meme motif
    /// exact que `SidebarView.panelFocus`, voir sa documentation.
    let panelFocus: FocusState<SlatePanelFocus?>.Binding

    public init(panelFocus: FocusState<SlatePanelFocus?>.Binding) {
        self.panelFocus = panelFocus
    }

    public var body: some View {
        Group {
            if let folder = appState.selectedFolder {
                folderContent(folder)
            } else {
                noFolderSelectedView
            }
        }
        .background(SlateColor.bgList)
        .sheet(item: $newFolderPromptContext) { context in
            FolderNamePromptSheet(context: context) { name in
                submitNewFolderForMove(context: context, name: name)
            }
        }
        .sheet(isPresented: $isSetPasswordSheetPresented) {
            SetPasswordSheet(
                isBiometricsAvailable: lockService.isBiometricsAvailable,
                onSubmit: { password, hint, allowBiometrics in
                    guard (try? lockService.setPassword(password, hint: hint, allowBiometrics: allowBiometrics)) != nil
                    else { return false }
                    isSetPasswordSheetPresented = false
                    lockPendingSelection()
                    return true
                },
                onCancel: {
                    isSetPasswordSheetPresented = false
                    pendingLockSelection = []
                }
            )
        }
        // Phase 14 : publie les actions de note (epingler/dupliquer/verrouiller/
        // corbeille) pour `SlateAppCommands` -- voir `NoteListView+MenuCommands.swift`.
        .focusedSceneValue(\.noteMenuActions, noteMenuCommandActions)
    }

    // MARK: - Dossier selectionne

    @ViewBuilder
    private func folderContent(_ folder: Folder) -> some View {
        // Une seule resolution des donnees par rendu (voir `resolveListData`), passee en
        // parametre a toute la sous-arborescence : `contentBody`/`listScrollView` ne
        // relisent plus jamais le store, ils ne font que presenter `data`. Avant cette
        // correction, `pinnedNotes`/`restNotes`/`dateGroups`/`folderHasAnyNotes(_:)`
        // etaient des computed properties SANS memoisation, relues a chaque acces (2 a 5
        // fois par rendu) - chacune declenchant un `context.fetch` complet du store,
        // synchrone sur le MainActor, y compris a chaque frappe dans le champ de
        // recherche (releve en revue de fin de Phase 4).
        let data = resolveListData(for: folder)
        VStack(spacing: 0) {
            // Point d'entree de la base pleine page (Phase 17, "les deux hebergements") :
            // au meme niveau que la liste des notes du dossier, voir
            // `DatabaseFolderSectionView`.
            DatabaseFolderSectionView(
                databases: folder.databases ?? [],
                selectedDatabaseID: appState.selectedDatabase?.id,
                onSelect: { appState.selectedDatabase = $0 },
                onCreate: { createDatabase(in: folder) }
            )
            searchBar
            contentBody(folder, data: data)
        }
    }

    @ViewBuilder
    private func contentBody(_ folder: Folder, data: NoteListData) -> some View {
        if !data.folderHasAnyNotes {
            NoteListEmptyStateView(kind: .noNotes(folderName: folder.name, onCreateNote: { createNote(in: folder) }))
        } else if data.pinnedNotes.isEmpty && data.restNotes.isEmpty {
            NoteListEmptyStateView(kind: .noResults(query: trimmedSearchText, folderName: folder.name))
        } else {
            listScrollView(data: data)
        }
    }

    private func listScrollView(data: NoteListData) -> some View {
        let allVisibleNotes = data.pinnedNotes + data.restNotes
        return ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if !data.pinnedNotes.isEmpty {
                    Section {
                        ForEach(data.pinnedNotes) { note in cellRow(note, allNotes: allVisibleNotes) }
                    } header: {
                        ListSectionHeader(
                            String(localized: "noteList.section.pinned", bundle: .module),
                            count: data.pinnedNotes.count,
                            background: SlateColor.bgList
                        )
                    }
                }

                // Spec E3 ("Tri") : en tri par titre, les groupes de date s'aplatissent
                // (Epinglees puis liste unique, sans en-tetes de date).
                if Self.shouldFlattenDateGroups(for: sortCriterion) {
                    ForEach(data.restNotes) { note in cellRow(note, allNotes: allVisibleNotes) }
                } else {
                    ForEach(data.dateGroups) { group in
                        Section {
                            ForEach(group.notes) { note in cellRow(note, allNotes: allVisibleNotes) }
                        } header: {
                            ListSectionHeader(
                                NoteDateGroupTitle.string(for: group.kind),
                                count: group.notes.count,
                                background: SlateColor.bgList
                            )
                        }
                    }
                }
            }
        }
        .onKeyPress(.upArrow) { handleVerticalArrow(-1) }
        .onKeyPress(.downArrow) { handleVerticalArrow(1) }
        .onKeyPress(.return) { handleReturn() }
        // Phase 14 (⌃⌘2) : cible du focus de panneau -- voir `SidebarView.panelFocus`
        // (meme motif exact). Uniquement disponible quand la liste affiche reellement
        // des notes : sans contenu, il n'y a rien vers quoi deplacer le focus.
        .focusable()
        .focused(panelFocus, equals: .list)
    }

    @ViewBuilder
    private func cellRow(_ note: Note, allNotes: [Note]) -> some View {
        NoteCell(
            note: note,
            isSelected: isCellSelected(note),
            isFocused: focusedNoteID == note.id,
            referenceDate: referenceDate(for: note),
            calendar: calendar,
            now: now
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleCellTap(note, in: allNotes)
        }
        .focusable()
        .focused($focusedNoteID, equals: note.id)
        .contextMenu {
            NoteContextMenuContent(
                selection: selectionForContextMenu(clicking: note),
                candidateFolders: candidateFoldersForMove,
                onTogglePin: { toggleSelectionPin(clicking: note) },
                onToggleFavorite: { toggleSelectionFavorite(clicking: note) },
                onLock: { lockSelection(clicking: note) },
                onDuplicate: { duplicateSelection(clicking: note) },
                onMove: { folder in moveSelection(clicking: note, to: folder) },
                onRequestNewFolder: { presentNewFolderForMove(clicking: note) },
                onCopyInternalLink: { copyInternalLink(for: note) },
                onMoveToTrash: { trashSelection(clicking: note) }
            )
        }
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.xs) {
            SearchField(
                text: $searchText,
                placeholder: String(localized: "noteList.search.placeholder", bundle: .module),
                clearButtonAccessibilityLabel: searchClearAccessibilityLabel
            )
            NoteListSortMenu(criterion: $sortCriterion, direction: $sortDirection)
        }
        // Spec E3 : "10 / 12" - aucun palier de `Spacing` ne tombe exactement sur 10 ;
        // `sm` (8pt) est le plus proche sans introduire un literal hors echelle.
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SlateColor.separator)
                .frame(height: SlateGeometry.strokeHairline)
        }
    }

    private var searchClearAccessibilityLabel: String {
        String(localized: "noteList.search.clearAccessibilityLabel", bundle: .module)
    }

    // MARK: - Aucun dossier selectionne

    private var noFolderSelectedView: some View {
        ContentUnavailableView(
            String(localized: "noteList.noFolderSelected.title", bundle: .module),
            systemImage: "note.text",
            description: Text(String(localized: "noteList.noFolderSelected.description", bundle: .module))
        )
    }

    // MARK: - Donnees derivees

    // Non `private` : lu depuis `NoteListView+DataResolution.swift` (meme module, extension
    // separee pour tenir la limite `file_length` de SwiftLint).
    var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Date de reference d'une note pour le regroupement ET l'affichage (voir
    /// `NoteDateGrouper`/`NoteCell`) : suit le critere de tri courant, `modifiedAt` en
    /// tri par titre (aucun groupe de date affiche dans ce cas, mais la cellule affiche
    /// quand meme une date coherente avec le comportement par defaut).
    ///
    /// Non `private` : lue depuis `NoteListView+DataResolution.swift` (meme module,
    /// extension separee pour tenir la limite `file_length` de SwiftLint).
    func referenceDate(for note: Note) -> Date {
        sortCriterion == .createdDate ? note.createdAt : note.modifiedAt
    }

    private var calendar: Calendar { .current }
    private var now: Date { .now }

    // MARK: - Navigation clavier

    /// Ordre visuel aplati de la liste (Epinglees puis le reste), pour la navigation
    /// clavier haut/bas : identique que le reste soit affiche groupe par date ou
    /// aplati par titre, puisque grouper ne re-trie jamais (voir `NoteDateGrouper`).
    ///
    /// Declenche par une action clavier (fleche haut/bas, retour), pas par le rendu de
    /// `body` - reste donc en dehors du perimetre de `resolveListData(for:)`/`folderContent(_:)`
    /// (qui vise le rendu). Une seule requete `NoteListQuery` par appui de touche (au lieu
    /// des deux requetes independantes de l'ancien code, `pinnedNotes` puis `restNotes`).
    var navigationOrder: [Note] {
        guard let folder = appState.selectedFolder else { return [] }
        let data = resolveListData(for: folder)
        return data.pinnedNotes + data.restNotes
    }

    private func handleVerticalArrow(_ delta: Int) -> KeyPress.Result {
        let order = navigationOrder
        guard !order.isEmpty else { return .ignored }

        guard let currentID = focusedNoteID, let index = order.firstIndex(where: { $0.id == currentID }) else {
            let first = order[0]
            focusedNoteID = first.id
            appState.selectedNote = first
            return .handled
        }

        let newIndex = index + delta
        guard order.indices.contains(newIndex) else { return .handled }
        let target = order[newIndex]
        focusedNoteID = target.id
        appState.selectedNote = target
        return .handled
    }

    private func handleReturn() -> KeyPress.Result {
        guard let id = focusedNoteID, let note = navigationOrder.first(where: { $0.id == id }) else { return .ignored }
        appState.selectedNote = note
        return .handled
    }

    // MARK: - Actions

    private func createNote(in folder: Folder) {
        let navigation = SidebarNavigation(context: modelContext)
        let title = String(localized: "sidebar.newNote.defaultTitle", bundle: .module)
        guard let note = try? navigation.createNote(titled: title, in: folder) else { return }
        appState.selectedNote = note
        focusedNoteID = note.id
    }

    /// Cree une base PLEINE PAGE dans `folder` (Phase 17, "les deux hebergements") via
    /// `DatabaseFolderCreation` (logique pure, testee independamment), puis insere
    /// reellement dans le `ModelContext` et selectionne la base pour l'ouvrir aussitot.
    private func createDatabase(in folder: Folder) {
        let created = DatabaseFolderCreation.makeDatabase(
            in: folder,
            name: String(localized: "database.folderSection.defaultName", bundle: .module),
            firstFieldName: String(localized: "database.folderSection.defaultFieldName", bundle: .module)
        )
        modelContext.insert(created.database)
        modelContext.insert(created.firstField)
        try? modelContext.save()
        appState.selectedDatabase = created.database
    }
}

extension NoteListView {
    /// Vrai si les groupes de date doivent s'aplatir en liste unique plutot que d'etre
    /// affiches sous des en-tetes de date (spec E3, "Tri" : "En tri par titre les
    /// groupes de date s'aplatissent (Epinglees puis liste unique)").
    ///
    /// Extraite en fonction pure et `static` (aucune dependance a `self`, a `AppState`
    /// ni a `ModelContext`) precisement pour rester testable sans construire de vue
    /// SwiftUI - ce point de decision vivait auparavant seulement inline dans
    /// `listScrollView`, sans couverture de test dediee (releve en revue de fin de
    /// Phase 4). Voir `NoteListViewLogicTests`.
    ///
    /// Note : l'ORDRE des notes a l'interieur du groupe/de la liste aplatie est
    /// identique dans les deux cas (`NoteDateGrouper` ne re-trie jamais, voir sa
    /// documentation) - la seule difference visible est la presence ou l'absence
    /// d'en-tetes de section, ce qui reste hors de portee d'un test unitaire sans
    /// inspection de vue SwiftUI.
    static func shouldFlattenDateGroups(for sortCriterion: NoteSortCriterion) -> Bool {
        sortCriterion == .title
    }
}

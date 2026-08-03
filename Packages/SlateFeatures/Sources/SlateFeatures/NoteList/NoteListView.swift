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
    @Environment(\.appState) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var sortCriterion: NoteSortCriterion = .modifiedDate
    @State private var sortDirection: SortDirection = .descending
    @FocusState private var focusedNoteID: Note.ID?

    public init() {}

    public var body: some View {
        Group {
            if let folder = appState.selectedFolder {
                folderContent(folder)
            } else {
                noFolderSelectedView
            }
        }
        .background(SlateColor.bgList)
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
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if !data.pinnedNotes.isEmpty {
                    Section {
                        ForEach(data.pinnedNotes) { note in cellRow(note) }
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
                    ForEach(data.restNotes) { note in cellRow(note) }
                } else {
                    ForEach(data.dateGroups) { group in
                        Section {
                            ForEach(group.notes) { note in cellRow(note) }
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
    }

    @ViewBuilder
    private func cellRow(_ note: Note) -> some View {
        NoteCell(
            note: note,
            isSelected: appState.selectedNote?.id == note.id,
            isFocused: focusedNoteID == note.id,
            referenceDate: referenceDate(for: note),
            calendar: calendar,
            now: now
        )
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedNote = note
            focusedNoteID = note.id
        }
        .focusable()
        .focused($focusedNoteID, equals: note.id)
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

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resultat d'une resolution de `resolveListData(for:)` : toute la matiere premiere
    /// necessaire a `contentBody`/`listScrollView` pour un rendu, obtenue en **une seule**
    /// requete `NoteListQuery` dans le cas courant (voir la documentation de
    /// `resolveListData(for:)`).
    private struct NoteListData {
        let pinnedNotes: [Note]
        let restNotes: [Note]
        let dateGroups: [NoteDateGroup]
        /// Vrai si le dossier contient au moins une note, INDEPENDAMMENT de toute
        /// recherche en cours - distingue "Aucune note" (dossier reellement vide) de
        /// "Aucun resultat" (recherche infructueuse dans un dossier non vide).
        let folderHasAnyNotes: Bool
    }

    /// Resout en **une seule** execution de `NoteListQuery.notes(in:...)` (au lieu des
    /// jusqu'a 5 executions par rendu avant cette correction - voir la note de
    /// `folderContent(_:)`) toute la matiere premiere necessaire a l'affichage : cette
    /// premiere requete recupere TOUTES les notes du dossier (`.all`, epinglees et non
    /// epinglees confondues) deja filtrees par la recherche et triees selon le critere
    /// courant ; epinglees et reste sont ensuite separees EN MEMOIRE par
    /// `Self.partitionByPinned`, qui preserve l'ordre - le resultat est donc rigoureusement
    /// identique (meme contenu, meme ordre, aucune duplication) a l'ancien code, qui
    /// obtenait les deux listes via deux requetes independantes (`.pinnedOnly` puis
    /// `.excludingPinned`) : une note epinglee ne peut apparaitre que dans `pinnedNotes`,
    /// jamais aussi dans `restNotes`/`dateGroups`.
    ///
    /// `folderHasAnyNotes` a besoin d'une information que la requete filtree par la
    /// recherche ne peut pas donner : distinguer un dossier reellement vide d'une
    /// recherche simplement infructueuse dans un dossier non vide. Une seconde requete
    /// (non filtree par la recherche, `NoteListQuery.notes(in:)`) n'est donc executee que
    /// dans le cas precis ou la recherche est non vide ET son resultat est vide - au
    /// maximum 2 requetes dans ce cas, 1 dans tous les autres (recherche vide, ou
    /// recherche non vide avec au moins un resultat, ce qui prouve deja que le dossier
    /// n'est pas vide sans requete supplementaire).
    private func resolveListData(for folder: Folder) -> NoteListData {
        let query = NoteListQuery(context: modelContext)
        let searchQuery = trimmedSearchText.isEmpty ? nil : trimmedSearchText

        let allNotes = (try? query.notes(
            in: folder,
            pinned: .all,
            matching: searchQuery,
            sortedBy: sortCriterion,
            direction: sortDirection
        )) ?? []

        let (pinnedNotes, restNotes) = Self.partitionByPinned(allNotes)

        let folderHasAnyNotes: Bool
        if searchQuery == nil {
            folderHasAnyNotes = !allNotes.isEmpty
        } else if !allNotes.isEmpty {
            folderHasAnyNotes = true
        } else {
            let unfilteredNotes = (try? query.notes(in: folder)) ?? []
            folderHasAnyNotes = !unfilteredNotes.isEmpty
        }

        let dateGroups = NoteDateGrouper.group(notes: restNotes, referenceDate: referenceDate)

        return NoteListData(
            pinnedNotes: pinnedNotes,
            restNotes: restNotes,
            dateGroups: dateGroups,
            folderHasAnyNotes: folderHasAnyNotes
        )
    }

    /// Separe `notes` (deja triees par l'appelant, voir `NoteListQuery`) en notes
    /// epinglees et notes restantes, en preservant STRICTEMENT l'ordre relatif d'entree
    /// dans chacun des deux groupes, sans perdre ni dupliquer aucune note.
    ///
    /// Extraite en fonction pure et `static` (aucune dependance a `self`) precisement
    /// pour etre testable sans construire de vue SwiftUI ni de `ModelContext` - voir
    /// `NoteListViewLogicTests`.
    ///
    /// Pourquoi ce partitionnement produit un resultat identique a deux requetes triees
    /// independamment (l'ancien comportement, un tri via `.pinnedOnly` puis un tri via
    /// `.excludingPinned`) : `notes` est deja totalement ordonnee par le comparateur de
    /// tri choisi (`NoteSorting.isOrderedBefore`, applique par `NoteListQuery`). Filtrer
    /// un sous-ensemble d'une sequence totalement ordonnee sans reordonner ses elements
    /// produit exactement la meme sequence que si ce sous-ensemble avait ete trie seul
    /// avec le meme comparateur - un comparateur total est, par definition, coherent avec
    /// lui-meme sur n'importe quel sous-ensemble.
    static func partitionByPinned(_ notes: [Note]) -> (pinnedNotes: [Note], restNotes: [Note]) {
        var pinnedNotes: [Note] = []
        var restNotes: [Note] = []
        for note in notes {
            if note.isPinned {
                pinnedNotes.append(note)
            } else {
                restNotes.append(note)
            }
        }
        return (pinnedNotes, restNotes)
    }

    /// Date de reference d'une note pour le regroupement ET l'affichage (voir
    /// `NoteDateGrouper`/`NoteCell`) : suit le critere de tri courant, `modifiedAt` en
    /// tri par titre (aucun groupe de date affiche dans ce cas, mais la cellule affiche
    /// quand meme une date coherente avec le comportement par defaut).
    private func referenceDate(for note: Note) -> Date {
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
    private var navigationOrder: [Note] {
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

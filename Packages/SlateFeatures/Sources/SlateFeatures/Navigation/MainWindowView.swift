import Foundation
import SwiftUI
import SwiftData
import SlateModel
import SlateUI

/// Coquille a 3 colonnes de l'application (`docs/03_sidebar_navigation.md`,
/// `design/03_sidebar/Slate_E1-E2_coquille-sidebar.html` section E1).
///
/// Assemble `SidebarView` (barre laterale, fonctionnelle), `NoteListView` (Phase 4) et
/// `NoteDetailColumnView` (bascule placeholder / rendu de note, Phase 5.1). Porte la
/// bascule des 3 etats de colonnes de la spec (voir `ColumnLayoutState`) et l'amorce
/// du workspace par defaut (voir `WorkspaceBootstrap`).
public struct MainWindowView: View {
    @Environment(\.appState) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lockService) private var lockService

    @State private var columnLayout = ColumnLayoutState.all
    @State private var bootstrapError: (any Error)?

    /// Focus de panneau (Phase 14, ⌃⌘1/⌃⌘2) : source UNIQUE, projetee vers
    /// `SidebarView`/`NoteListView` via leur parametre `panelFocus` (voir
    /// `SlatePanelFocus`). Une commande de la barre de menu (`SlateAppCommands`) se
    /// contente d'assigner cette valeur -- c'est `.focused(panelFocus, equals: ...)`,
    /// cote de chaque panneau, qui traduit ce changement en un VRAI deplacement du
    /// focus clavier systeme, exactement comme un clic l'aurait fait. L'editeur n'a
    /// pas d'entree ici : voir `SlatePanelFocus`.
    @FocusState private var focusedPanel: SlatePanelFocus?

    /// Notification distribuee emise par macOS au verrouillage de l'ecran (aucune API
    /// SwiftUI/`NSWorkspace` dediee pour cet evenement precis, contrairement au
    /// sommeil de l'ecran -- c'est la notification que le systeme lui-meme utilise
    /// pour tout ce qui doit reagir a un verrouillage). Voir
    /// `AutoRelockCoordinator.relockAllUnlockedNotes` : "reverrouillage automatique...
    /// au verrouillage de l'app" (`docs/12_verrouillage.md`).
    private static let screenLockedNotification = Notification.Name("com.apple.screenIsLocked")

    public init() {}

    public var body: some View {
        Group {
            if let bootstrapError {
                WorkspaceBootstrapErrorView(error: bootstrapError)
            } else {
                splitView
            }
        }
        // Point de branchement REEL de `NoteActionsProviding` (voir
        // `NoteActionsProvidingAdapter`) : toutes les vues descendantes (sidebar, liste
        // de notes, corbeille) lisent `\.noteActions` depuis l'environnement plutot que
        // de construire elles-memes un `NoteActionsService`.
        .environment(\.noteActions, NoteActionsProvidingAdapter(modelContext: modelContext))
        .task {
            await bootstrapWorkspaceIfNeeded()
            purgeExpiredTrash()
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: Self.screenLockedNotification)) { _ in
            AutoRelockCoordinator.relockAllUnlockedNotes(appState: appState, lockService: lockService)
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: columnVisibilityBinding) {
            SidebarView(panelFocus: $focusedPanel)
                .slateColumnWidth(NavigationLayout.sidebarWidth)
        } content: {
            NoteListView(panelFocus: $focusedPanel)
                .slateColumnWidth(listColumnWidth)
        } detail: {
            NoteDetailColumnView()
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbarContent }
        .background {
            // Boutons invisibles portant les raccourcis clavier qui n'ont pas
            // d'equivalent visible dans la toolbar (spec E1 : Cmd+Ctrl+F = mode
            // focus, geste clavier uniquement).
            Button("") { columnLayout.toggleFocusMode() }
                .keyboardShortcut("f", modifiers: [.command, .control])
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .animation(
            SlateMotion.animation(duration: SlateMotion.durationSlow, reduceMotion: reduceMotion),
            value: columnLayout
        )
        // Phase 14 : publie les bascules de colonnes pour `SlateAppCommands` (menu
        // Affichage). Pas de `.keyboardShortcut` duplique cote menu (voir sa
        // documentation) : Cmd+1/Cmd+2/Ctrl+Cmd+F restent portes par les boutons
        // locaux ci-dessus, seule source reelle de la combinaison.
        .focusedSceneValue(\.toggleSidebarAction, { columnLayout.toggleSidebar() })
        .focusedSceneValue(\.toggleListAction, { columnLayout.toggleList() })
        .focusedSceneValue(\.toggleFocusModeAction, { columnLayout.toggleFocusMode() })
        // Phase 14 (⌃⌘1/⌃⌘2) : deplacement du focus clavier entre panneaux -- voir
        // `focusedPanel`/`SlatePanelFocus`.
        .focusedSceneValue(\.focusSidebarAction, { focusedPanel = .sidebar })
        .focusedSceneValue(\.focusListAction, { focusedPanel = .list })
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                columnLayout.toggleSidebar()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .keyboardShortcut("1", modifiers: .command)
            .help(String(localized: "toolbar.toggleSidebar.help", bundle: .module))
            .accessibilityLabel(String(localized: "toolbar.toggleSidebar", bundle: .module))

            Button {
                columnLayout.toggleList()
            } label: {
                Image(systemName: "list.bullet")
            }
            .keyboardShortcut("2", modifiers: .command)
            .help(String(localized: "toolbar.toggleList.help", bundle: .module))
            .accessibilityLabel(String(localized: "toolbar.toggleList", bundle: .module))
        }

        ToolbarItem(placement: .principal) {
            SyncStatusView()
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                // Phase 15 (recherche plein texte) : non implementee ici.
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .disabled(true)
            .help(String(localized: "toolbar.search.disabledHelp", bundle: .module))
            .accessibilityLabel(String(localized: "toolbar.search", bundle: .module))

            Button {
                // IA : phase ulterieure, non implementee ici.
            } label: {
                Image(systemName: "sparkles")
            }
            .disabled(true)
            .help(String(localized: "toolbar.ai.disabledHelp", bundle: .module))
            .accessibilityLabel(String(localized: "toolbar.ai", bundle: .module))

            Button {
                // Editeur de blocs : Phase 5, non implemente ici.
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .disabled(true)
            .help(String(localized: "toolbar.edit.disabledHelp", bundle: .module))
            .accessibilityLabel(String(localized: "toolbar.edit", bundle: .module))
        }
    }

    /// Binding derive de `columnLayout` pour le `NavigationSplitView` natif. Le
    /// setter ne traduit que les deux etats representables nativement (sidebar
    /// visible/masquee) : le mode focus et la liste (Cmd+2) restent pilotes
    /// exclusivement par nos propres commandes (voir `ColumnLayoutState`).
    private var columnVisibilityBinding: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { columnLayout.nativeVisibility },
            set: { newValue in
                guard !columnLayout.isFocusMode else { return }
                switch newValue {
                case .all:
                    columnLayout.setSidebarVisible(true)
                case .doubleColumn:
                    columnLayout.setSidebarVisible(false)
                default:
                    break
                }
            }
        )
    }

    private var listColumnWidth: ColumnWidth {
        columnLayout.isListColumnCollapsed
            ? ColumnWidth(min: 0, ideal: 0, max: 0)
            : NavigationLayout.listWidth
    }

    private func bootstrapWorkspaceIfNeeded() async {
        guard appState.selectedWorkspace == nil else { return }
        do {
            let workspace = try WorkspaceBootstrap.ensureDefaultWorkspace(in: modelContext)
            appState.selectedWorkspace = workspace
        } catch {
            bootstrapError = error
        }
    }

    /// Purge automatique de la corbeille au lancement (`docs/11_organisation_notes.md` :
    /// "tache de purge au lancement"). Echec silencieux (`try?`, meme convention que le
    /// reste de la coquille) : une purge manquee n'empeche pas l'app de demarrer, elle
    /// sera retentee au prochain lancement.
    private func purgeExpiredTrash() {
        _ = try? NoteActionsProvidingAdapter(modelContext: modelContext).purgeExpiredTrash(now: .now)
    }
}

import SwiftUI
import SwiftData
import SlateModel
import SlateUI

/// Coquille a 3 colonnes de l'application (`docs/03_sidebar_navigation.md`,
/// `design/03_sidebar/Slate_E1-E2_coquille-sidebar.html` section E1).
///
/// Assemble `SidebarView` (barre laterale, fonctionnelle), et deux placeholders
/// explicites pour la liste de notes (Phase 4) et l'editeur (Phase 5). Porte la
/// bascule des 3 etats de colonnes de la spec (voir `ColumnLayoutState`) et l'amorce
/// du workspace par defaut (voir `WorkspaceBootstrap`).
public struct MainWindowView: View {
    @Environment(\.appState) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var columnLayout = ColumnLayoutState.all
    @State private var bootstrapError: (any Error)?

    public init() {}

    public var body: some View {
        Group {
            if let bootstrapError {
                WorkspaceBootstrapErrorView(error: bootstrapError)
            } else {
                splitView
            }
        }
        .task {
            await bootstrapWorkspaceIfNeeded()
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: columnVisibilityBinding) {
            SidebarView()
                .slateColumnWidth(NavigationLayout.sidebarWidth)
        } content: {
            NoteListView()
                .slateColumnWidth(listColumnWidth)
        } detail: {
            NoteDetailColumnPlaceholderView()
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
}

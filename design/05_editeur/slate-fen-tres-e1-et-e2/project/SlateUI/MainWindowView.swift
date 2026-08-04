//  MainWindowView.swift — E1, coquille 3 colonnes.
//
//  Proportions par défaut (fenêtre 1280×800) :
//    sidebar 240 pt (min 180, max 320, idéal 240)
//    liste   300 pt (min 260, max 420, idéal 300)
//    éditeur reste (min 480) — colonne de texte centrée à 720 pt max
//  Fenêtre minimale 1000×700 : 200 + 260 + 540.
//
//  Collapse :
//    ⌘1 masque/affiche la sidebar (columnVisibility .detailOnly ↔ .all)
//    ⌘2 masque/affiche la liste  → mode « focus » éditeur seul
//    ⌘⌃F bascule le mode focus complet (sidebar + liste masquées)
//  Sous 900 pt de large, la liste se replie automatiquement (préparation iOS :
//  les colonnes deviennent une pile / des feuilles).

import SwiftUI

public struct MainWindowView: View {
    @State private var state = SlateSidebarState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var editorState = SlateEditorState.demo
    @State private var listCollapsed = false
    @State private var accent: SlateAccent = .blue

    @State private var noteSelection: UUID?

    let workspace: SlateWorkspace
    let favorites: [SlateFolder]
    let spaces: [SlateFolder]
    let notes: [SlateNote]
    var currentFolderName: String = "Toutes les notes"

    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(state: state, workspace: workspace, favorites: favorites, spaces: spaces)
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 320)
        } content: {
            if !listCollapsed {
                NoteListView(notes: notes, folderName: currentFolderName, selection: $noteSelection)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
            }
        } detail: {
            EditorView(state: editorState)
                .navigationSplitViewColumnWidth(min: 480, ideal: 740, max: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .background(SlateColors.bgWindow)
        .frame(minWidth: 1000, minHeight: 700)
        .environment(\.slateAccent, accent)
        // La sélection passe en « inactive » quand la fenêtre perd le premier plan.
        .onChange(of: controlActiveState) { _, newValue in
            state.windowIsKey = (newValue == .key || newValue == .active)
        }
        .toolbar { toolbarContent }
        .background {
            // Raccourcis colonnes (⌘1 / ⌘2 / ⌘⌃F)
            Group {
                Button("") { toggleSidebar() }.keyboardShortcut("1", modifiers: .command)
                Button("") { toggleList() }.keyboardShortcut("2", modifiers: .command)
                Button("") { toggleFocusMode() }.keyboardShortcut("f", modifiers: [.command, .control])
            }
            .opacity(0).accessibilityHidden(true)
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: toggleSidebar) { Image(systemName: "sidebar.leading") }
                .help("Masquer la barre latérale (⌘1)")
                .accessibilityLabel("Basculer la barre latérale")
        }
        ToolbarItem(placement: .navigation) {
            Button(action: toggleList) { Image(systemName: "list.bullet.rectangle") }
                .help("Masquer la liste de notes (⌘2)")
                .accessibilityLabel("Basculer la liste de notes")
        }
        ToolbarItemGroup(placement: .principal) {
            Spacer()
            SyncIndicator(state: .upToDate)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: {}) { Image(systemName: "magnifyingglass") }
                .help("Rechercher (⌘⇧F)")
            Button(action: {}) { Image(systemName: "sparkles") }
                .help("Assistant IA")
            Button(action: {}) { Image(systemName: "square.and.pencil") }
                .help("Nouvelle note (⌘N)")
        }
    }

    private func toggleSidebar() {
        withAnimation(SlateMotion.standard(SlateMotion.slow, reduceMotion: reduceMotion)) {
            columnVisibility = (columnVisibility == .detailOnly) ? .all : .detailOnly
        }
    }
    private func toggleList() {
        withAnimation(SlateMotion.standard(SlateMotion.slow, reduceMotion: reduceMotion)) {
            listCollapsed.toggle()
        }
    }
    /// Mode focus : éditeur seul, la toolbar reste accessible.
    private func toggleFocusMode() {
        withAnimation(SlateMotion.standard(SlateMotion.slow, reduceMotion: reduceMotion)) {
            let focused = (columnVisibility == .detailOnly && listCollapsed)
            columnVisibility = focused ? .all : .detailOnly
            listCollapsed = !focused
        }
    }
}

// MARK: - Indicateur de sync (E16, discret, jamais bloquant)

public struct SyncIndicator: View {
    public enum SyncState { case syncing, upToDate, error }
    public let state: SyncState
    public init(state: SyncState) { self.state = state }

    public var body: some View {
        HStack(spacing: SlateSpace.xs) {
            switch state {
            case .syncing:
                ProgressView().controlSize(.small)
                Text("Synchronisation…")
            case .upToDate:
                Image(systemName: "checkmark.icloud").foregroundStyle(SlateColors.textTertiary)
                Text("À jour")
            case .error:
                Image(systemName: "exclamationmark.icloud").foregroundStyle(SlateColors.error)
                Text("Erreur de sync")
            }
        }
        .slateFont(.caption)
        .foregroundStyle(state == .error ? SlateColors.error : SlateColors.textSecondary)
        .accessibilityLabel("État de synchronisation iCloud")
    }
}

// L'éditeur est livré en E4 → SlateUI/EditorView.swift.

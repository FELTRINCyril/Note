//  SidebarView.swift — E2, barre latérale complète.

import SwiftUI

public struct SidebarView: View {
    @Bindable var state: SlateSidebarState
    var workspace: SlateWorkspace
    var favorites: [SlateFolder]
    var spaces: [SlateFolder]
    var onNewFolder: () -> Void = {}
    var onNewNote: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onOpenTrash: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        VStack(spacing: 0) {
            WorkspaceSwitcher(current: workspace)
                .padding(.top, SlateSpace.s)
                .padding(.bottom, SlateSpace.xs)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(favorites) { f in
                            FolderRow(folder: f, state: state)
                        }
                    } header: {
                        SidebarSectionHeader("Favoris")
                    }

                    Section {
                        ForEach(spaces) { f in
                            FolderRow(folder: f, state: state) { dragged, target, position in
                                // Réordonnancement — la mutation du modèle vit dans le store.
                                NotificationCenter.default.post(name: .slateMoveFolder, object: nil,
                                    userInfo: ["dragged": dragged, "target": target, "position": String(describing: position)])
                            }
                        }
                    } header: {
                        SidebarSectionHeader("Espaces", action: onNewFolder)
                    }
                }
                .padding(.bottom, SlateSpace.m)
            }
            .scrollContentBackground(.hidden)

            Divider().overlay(SlateColors.separator)

            // Pied : Réglages + Corbeille + création
            HStack(spacing: SlateSpace.xs) {
                Button(action: onOpenSettings) {
                    Label("Réglages", systemImage: "gearshape")
                }
                .accessibilityLabel("Ouvrir les réglages")
                Button(action: onOpenTrash) {
                    Label("Corbeille", systemImage: "trash")
                }
                .accessibilityLabel("Ouvrir la corbeille")
                Spacer()
                Button(action: onNewFolder) { Image(systemName: "folder.badge.plus") }
                    .accessibilityLabel("Nouveau dossier")
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button(action: onNewNote) { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("Nouvelle note")
                    .keyboardShortcut("n", modifiers: .command)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .font(.system(size: SlateMetrics.iconM))
            .foregroundStyle(SlateColors.textSecondary)
            .padding(.horizontal, SlateSpace.m)
            .frame(height: SlateMetrics.controlL + SlateSpace.xs)
        }
        .background(SlateSidebarBackground())
        .accessibilityLabel("Barre latérale")
    }
}

public extension Notification.Name {
    static let slateMoveFolder = Notification.Name("slate.moveFolder")
}

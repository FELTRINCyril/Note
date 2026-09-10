//  FolderRow.swift — SlateUI
//  Arbre récursif de dossiers/espaces. Pliage, indentation par niveau,
//  drag & drop de réorganisation (insertion entre lignes ou dépôt dans un dossier).

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Modèle

public struct SlateFolder: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var systemImage: String
    public var tint: SlateAccent
    public var noteCount: Int
    public var children: [SlateFolder]

    public init(id: UUID = UUID(), name: String, systemImage: String = "folder.fill",
                tint: SlateAccent = .yellow, noteCount: Int = 0, children: [SlateFolder] = []) {
        self.id = id; self.name = name; self.systemImage = systemImage
        self.tint = tint; self.noteCount = noteCount; self.children = children
    }
    public var isLeaf: Bool { children.isEmpty }
}

/// État d'interaction partagé par l'arbre (une seule source de vérité).
@Observable
public final class SlateSidebarState {
    public var expanded: Set<UUID> = []
    public var selection: UUID?
    public var keyboardFocus: UUID?          // focus clavier — distinct de `selection`
    public var draggingID: UUID?
    public var dropTargetID: UUID?
    public var dropPosition: SlateDropTarget = .none
    public var windowIsKey: Bool = true

    public init() {}
    public func isExpanded(_ id: UUID) -> Bool { expanded.contains(id) }
    public func toggle(_ id: UUID) { expanded.formSymmetricDifference([id]) }
    public func selectionState(for id: UUID) -> SlateRowSelection {
        guard selection == id else { return .none }
        return windowIsKey ? .active : .inactive
    }
    public func dropTarget(for id: UUID) -> SlateDropTarget {
        dropTargetID == id ? dropPosition : .none
    }
}

// MARK: - Ligne récursive

public struct FolderRow: View {
    let folder: SlateFolder
    var level: Int = 0
    @Bindable var state: SlateSidebarState
    var onMove: ((_ dragged: UUID, _ target: UUID, _ position: SlateDropTarget) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(folder: SlateFolder, level: Int = 0, state: SlateSidebarState,
                onMove: ((UUID, UUID, SlateDropTarget) -> Void)? = nil) {
        self.folder = folder; self.level = level; self.state = state; self.onMove = onMove
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarRow(
                title: folder.name,
                systemImage: folder.systemImage,
                iconTint: folder.tint.color,
                level: level,
                isExpanded: folder.isLeaf ? nil : state.isExpanded(folder.id),
                badge: folder.noteCount > 0 ? "\(folder.noteCount)" : nil,
                accessory: {
                    Menu {
                        Button("Nouvelle note") {}
                        Button("Nouveau sous-dossier") {}
                        Divider()
                        Button("Renommer") {}
                        Button("Supprimer", role: .destructive) {}
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel("Actions sur \(folder.name)")
                },
                selection: state.selectionState(for: folder.id),
                dropTarget: state.dropTarget(for: folder.id),
                isDragging: state.draggingID == folder.id,
                onToggleExpand: {
                    withAnimation(SlateMotion.standard(reduceMotion: reduceMotion)) {
                        state.toggle(folder.id)
                    }
                },
                onActivate: { state.selection = folder.id }
            )
            .draggable(folder.id.uuidString) {
                // Aperçu « ghost » du drag (opacity.dragGhost appliqué par la ligne source).
                Label(folder.name, systemImage: folder.systemImage)
                    .slateFont(.sidebarItem)
                    .padding(.horizontal, SlateSpace.s)
                    .padding(.vertical, SlateSpace.xs)
                    .background(SlateColors.surfacePrimary, in: RoundedRectangle(cornerRadius: SlateRadius.s))
                    .slateShadow(.high)
            }
            .dropDestination(for: String.self) { items, location in
                guard let dragged = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                onMove?(dragged, folder.id, state.dropPosition)
                state.dropTargetID = nil; state.dropPosition = .none
                return true
            } isTargeted: { targeted in
                withAnimation(SlateMotion.standard(SlateMotion.fast, reduceMotion: reduceMotion)) {
                    state.dropTargetID = targeted ? folder.id : nil
                    // Dossier → dépôt dedans ; feuille → insertion en dessous.
                    state.dropPosition = targeted ? (folder.isLeaf ? .insertBelow : .onRow) : .none
                }
            }

            if !folder.isLeaf, state.isExpanded(folder.id) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(folder.children) { child in
                        FolderRow(folder: child, level: level + 1, state: state, onMove: onMove)
                    }
                }
                .transition(reduceMotion
                            ? .opacity
                            : .asymmetric(insertion: .opacity.combined(with: .move(edge: .top)),
                                          removal: .opacity))
            }
        }
    }
}

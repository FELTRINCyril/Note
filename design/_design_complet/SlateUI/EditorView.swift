//  EditorView.swift — SlateUI · E4
//  Troisième colonne de la coquille E1 : coquille de l'éditeur + chrome des blocs.
//  Hors périmètre (écrans séparés) : barre flottante de formatage inline et H1–H6 (E6),
//  blocs spéciaux code / tableau / callout (E7). Ici les blocs sont des paragraphes.

import SwiftUI

// MARK: - Modèle minimal de bloc (le type réel arrive avec E6/E7)

public struct SlateBlock: Identifiable, Equatable {
    public let id: String
    public var text: String
    public init(id: String = UUID().uuidString, text: String) { self.id = id; self.text = text }
    var isEmpty: Bool { text.isEmpty }
}

@Observable public final class SlateEditorState {
    public var header = SlateNoteHeader()
    public var blocks: [SlateBlock] = []
    /// Bloc en édition (caret dedans).
    public var focusedBlockID: String? = nil
    /// Sélection de blocs entiers (Échap, ⌘A, Maj+clic, clic sur la poignée).
    public var selectedBlockIDs: Set<String> = []
    /// Focus clavier de navigation, distinct de la sélection.
    public var keyboardFocusedBlockID: String? = nil
    /// Cible de dépôt courante pendant un drag.
    public var dropTargetBlockID: String? = nil
    public var dropEdge: Edge = .bottom
    public var isWindowActive = true
    public init() {}

    func state(for block: SlateBlock) -> SlateBlockState {
        if selectedBlockIDs.contains(block.id) { return .selected }
        if keyboardFocusedBlockID == block.id { return .keyboardFocused }
        if focusedBlockID == block.id { return .focused }
        return .normal
    }

    /// Position dans la plage sélectionnée → coins de l'aplat.
    func rangePosition(for index: Int) -> SlateBlockRangePosition {
        let id = blocks[index].id
        guard selectedBlockIDs.contains(id) else { return .single }
        let prevSelected = index > 0 && selectedBlockIDs.contains(blocks[index - 1].id)
        let nextSelected = index < blocks.count - 1 && selectedBlockIDs.contains(blocks[index + 1].id)
        switch (prevSelected, nextSelected) {
        case (false, false): return .single
        case (false, true):  return .first
        case (true, true):   return .middle
        case (true, false):  return .last
        }
    }
}

// MARK: - Écran

public struct EditorView: View {
    @Bindable var state: SlateEditorState

    @Environment(\.slateAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(state: SlateEditorState) { self.state = state }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(SlateColors.separator)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NoteHeaderView(header: $state.header,
                                   focusedField: state.focusedBlockID == nil ? .title : nil)

                    EditorContentColumn {
                        ForEach(Array(state.blocks.enumerated()), id: \.element.id) { index, block in
                            BlockContainer(
                                state: state.state(for: block),
                                rangePosition: state.rangePosition(for: index),
                                isEmpty: block.isEmpty,
                                dropEdge: state.dropTargetBlockID == block.id ? state.dropEdge : nil,
                                firstLineHeight: 15 * SlateEditorMetrics.paragraphLineHeight,
                                blockID: block.id,
                                onInsert: { insert(after: index) },
                                onMenu: { state.selectedBlockIDs = [block.id] }
                            ) {
                                paragraph(block)
                            }
                            .onTapGesture {
                                state.selectedBlockIDs = []
                                state.keyboardFocusedBlockID = nil
                                state.focusedBlockID = block.id
                            }
                        }

                        // Zone de clic « écrire à la suite » : un clic crée un bloc vide.
                        Rectangle().fill(.clear)
                            .frame(height: SlateEditorMetrics.contentBottomPadding)
                            .contentShape(Rectangle())
                            .onTapGesture { insert(after: state.blocks.count - 1) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SlateColors.bgEditor)
        }
        .background(SlateColors.bgEditor)
        // Échap : passer de l'édition du texte à la sélection du bloc entier.
        .onExitCommand {
            if let id = state.focusedBlockID {
                state.focusedBlockID = nil
                state.selectedBlockIDs = [id]
            }
        }
    }

    // MARK: Paragraphe (contenu par défaut d'un bloc)

    @ViewBuilder private func paragraph(_ block: SlateBlock) -> some View {
        let isFocused = state.focusedBlockID == block.id
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(block.text)
                .slateFont(.body)
                .foregroundStyle(SlateColors.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if isFocused {
                BlockCaret(lineHeight: 15 * SlateEditorMetrics.paragraphLineHeight)
                    .padding(.leading, block.isEmpty ? 0 : 1)
            }
            Spacer(minLength: 0)
        }
    }

    private func insert(after index: Int) {
        let new = SlateBlock(text: "")
        let target = min(max(index + 1, 0), state.blocks.count)
        state.blocks.insert(new, at: target)
        state.selectedBlockIDs = []
        state.focusedBlockID = new.id
    }

    // MARK: Chrome haut de la colonne (44 pt)

    private var toolbar: some View {
        HStack(spacing: SlateSpace.s) {
            HStack(spacing: SlateSpace.xs) {
                Text("Produit").slateFont(.label).foregroundStyle(SlateColors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SlateColors.textTertiary)
                Text(state.header.title.isEmpty ? "Sans titre" : state.header.title)
                    .slateFont(.label)
                    .foregroundStyle(SlateColors.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: SlateSpace.l)
            toolbarButton("star", "Ajouter aux favoris")
            toolbarButton("lock", "Verrouiller la note")
            toolbarButton("square.and.arrow.up", "Partager")
            toolbarButton("ellipsis", "Plus d'actions")
        }
        .padding(.horizontal, SlateSpace.l)
        .frame(height: SlateEditorMetrics.toolbarHeight)
        .background(SlateColors.bgEditor)
    }

    private func toolbarButton(_ symbol: String, _ help: String) -> some View {
        Button { } label: {
            Image(systemName: symbol)
                .font(.system(size: SlateMetrics.iconS))
                .foregroundStyle(SlateColors.textSecondary)
                .frame(width: SlateMetrics.controlM, height: SlateMetrics.controlM)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Aperçus (deux thèmes)

#Preview("E4 — clair") {
    EditorView(state: .demo).frame(width: 900, height: 700).environment(\.colorScheme, .light)
}
#Preview("E4 — sombre") {
    EditorView(state: .demo).frame(width: 900, height: 700).environment(\.colorScheme, .dark)
}

extension SlateEditorState {
    static var demo: SlateEditorState {
        let s = SlateEditorState()
        s.header = SlateNoteHeader(title: "Feuille de route Q3",
                                   subtitle: "Ce que l'on livre avant septembre, et ce que l'on assume de reporter.",
                                   icon: "🧭", coverImageName: nil,
                                   metaLine: "Modifiée aujourd'hui à 14:22 · 428 mots")
        s.blocks = [
            .init(id: "b1", text: "L'éditeur de blocs est le cœur de la version 1 : tant qu'écrire n'est pas fluide, le reste ne compte pas."),
            .init(id: "b2", text: "Trois chantiers en parallèle — édition, synchronisation, verrouillage."),
            .init(id: "b3", text: "")
        ]
        s.focusedBlockID = "b3"
        return s
    }
}

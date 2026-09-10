//  NoteCell.swift — SlateUI (E3)
//  Cellule de note : titre, extrait 1–2 lignes, date relative, indicateurs.
//  Hauteur `row.height.noteCell` = 64 pt en minimum (s'étire en Dynamic Type).

import SwiftUI

public struct SlateNote: Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var snippet: String
    public var date: Date
    public var isPinned: Bool
    public var isLocked: Bool
    public var isFavorite: Bool
    public var folderTint: SlateAccent?

    public init(id: UUID = UUID(), title: String, snippet: String, date: Date,
                isPinned: Bool = false, isLocked: Bool = false, isFavorite: Bool = false,
                folderTint: SlateAccent? = nil) {
        self.id = id; self.title = title; self.snippet = snippet; self.date = date
        self.isPinned = isPinned; self.isLocked = isLocked; self.isFavorite = isFavorite
        self.folderTint = folderTint
    }

    /// Extrait affiché : masqué si la note est verrouillée (E10).
    public var displaySnippet: String { isLocked ? "Note verrouillée" : snippet }
}

public struct NoteCell: View {
    let note: SlateNote
    var selection: SlateRowSelection = .none
    var isKeyboardFocused: Bool = false
    var relativeDate: String
    var onActivate: (() -> Void)?

    @Environment(\.slateAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isHovering = false
    @State private var isPressed = false
    @FocusState private var focused: Bool

    public init(note: SlateNote, relativeDate: String, selection: SlateRowSelection = .none,
                isKeyboardFocused: Bool = false, onActivate: (() -> Void)? = nil) {
        self.note = note; self.relativeDate = relativeDate; self.selection = selection
        self.isKeyboardFocused = isKeyboardFocused; self.onActivate = onActivate
    }

    private var isSelectedActive: Bool { selection == .active }
    private var titleColor: Color { isSelectedActive ? accent.onAccent : SlateColors.textPrimary }
    private var secondaryColor: Color { isSelectedActive ? accent.onAccentSecondary : SlateColors.textSecondary }
    private var tertiaryColor: Color { isSelectedActive ? accent.onAccentSecondary : SlateColors.textTertiary }

    public var body: some View {
        VStack(alignment: .leading, spacing: SlateSpace.xxs) {
            HStack(spacing: SlateSpace.xs) {
                indicators
                Text(note.title.isEmpty ? "Nouvelle note" : note.title)
                    .slateFont(.listTitle)
                    .foregroundStyle(note.title.isEmpty ? tertiaryColor : titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(note.displaySnippet)
                .slateFont(.listSnippet)
                .foregroundStyle(note.isLocked && !isSelectedActive ? SlateColors.textTertiary : secondaryColor)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
            Text(relativeDate)
                .slateFont(.caption)
                .foregroundStyle(tertiaryColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SlateSpace.l - SlateSpace.xxs)
        .padding(.vertical, SlateSpace.s + SlateSpace.xxs)
        .frame(minHeight: SlateMetrics.noteCellHeight, alignment: .leading)
        .background(background)
        .overlay(alignment: .bottom) { separator }
        .overlay(focusRing)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(SlateMotion.standard(SlateMotion.fast, reduceMotion: reduceMotion)) {
                isHovering = hovering
            }
        }
        .onTapGesture { onActivate?() }
        .focusable()
        .focused($focused)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(voiceOverLabel)
        .accessibilityAddTraits(selection == .none ? [] : [.isSelected])
    }

    private var background: Color {
        switch selection {
        case .active:   return isPressed ? accent.selectionFillPressed : accent.selectionFill
        case .inactive: return SlateColors.stateSelectedInactive
        case .none:     return isHovering ? SlateColors.stateHover : .clear
        }
    }

    /// Filet inter-cellules, masqué quand la cellule est sélectionnée (comme Notes).
    @ViewBuilder private var separator: some View {
        if selection == .none {
            Rectangle().fill(SlateColors.separator).frame(height: SlateStroke.hairline)
                .padding(.leading, SlateSpace.l - SlateSpace.xxs)
        }
    }

    /// Focus clavier : anneau, jamais un aplat — reste distinct de la sélection souris.
    @ViewBuilder private var focusRing: some View {
        if focused || isKeyboardFocused {
            Rectangle()
                .strokeBorder(accent.focusRing, lineWidth: SlateStroke.focusRingWidth)
                .transition(.opacity)
        }
    }

    /// Indicateurs — chaque état a un glyphe distinct : jamais la couleur seule.
    @ViewBuilder private var indicators: some View {
        HStack(spacing: SlateSpace.xxs) {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(isSelectedActive ? accent.onAccent : accent.color)
                    .accessibilityHidden(true)
            }
            if note.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(isSelectedActive ? accent.onAccent : SlateColors.warning)
                    .accessibilityHidden(true)
            }
            if note.isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(isSelectedActive ? accent.onAccentSecondary : SlateColors.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .opacity(note.isPinned || note.isFavorite || note.isLocked ? 1 : 0)
        .frame(width: indicatorWidth, alignment: .leading)
    }

    private var indicatorWidth: CGFloat? {
        let n = [note.isPinned, note.isFavorite, note.isLocked].filter { $0 }.count
        return n == 0 ? 0 : nil
    }

    private var voiceOverLabel: String {
        var parts = [note.title.isEmpty ? "Nouvelle note" : note.title]
        if note.isPinned { parts.append("épinglée") }
        if note.isFavorite { parts.append("favorite") }
        if note.isLocked { parts.append("verrouillée") }
        parts.append(relativeDate)
        if !note.isLocked { parts.append(note.snippet) }
        return parts.joined(separator: ", ")
    }
}

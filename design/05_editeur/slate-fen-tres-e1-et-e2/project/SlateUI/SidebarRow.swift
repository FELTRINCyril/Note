//  SidebarRow.swift — SlateUI
//  Ligne générique de barre latérale : icône colorée + libellé + accessoire.
//  Couvre : normal · survol · sélection (fenêtre active) · sélection inactive ·
//           focus clavier (distinct de la sélection) · cible de dépôt.

import SwiftUI

// MARK: - États

public enum SlateRowSelection: Equatable {
    case none
    /// Sélection souris, fenêtre au premier plan → aplat d'accent, texte `text.onAccent`.
    case active
    /// Fenêtre inactive → aplat neutre `state.selectedInactive`, texte `text.primary`.
    case inactive
}

/// Indicateur de dépôt du drag & drop de réorganisation.
public enum SlateDropTarget: Equatable {
    case none
    /// Ligne d'insertion 2 pt en accent, alignée sur l'indentation cible.
    case insertAbove, insertBelow
    /// Dépôt *dans* un dossier → halo d'accent sur toute la ligne.
    case onRow
}

// MARK: - Ligne

public struct SidebarRow<Accessory: View>: View {
    // Contenu
    let title: String
    let systemImage: String
    var iconTint: Color?
    var level: Int = 0
    /// Chevron : `nil` = pas de chevron (feuille), sinon état plié/déplié.
    var isExpanded: Bool?
    var badge: String?
    var isDisabled: Bool = false
    @ViewBuilder var accessory: () -> Accessory

    // États
    var selection: SlateRowSelection = .none
    var dropTarget: SlateDropTarget = .none
    var isDragging: Bool = false
    var onToggleExpand: (() -> Void)?
    var onActivate: (() -> Void)?

    @Environment(\.slateAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var isFocused          // focus clavier de la ligne
    @FocusState private var focused: Bool
    @State private var isHovering = false
    @State private var isPressed = false

    public var body: some View {
        ZStack(alignment: .leading) {
            background
            content
        }
        .frame(minHeight: SlateMetrics.sidebarRowHeight)
        .contentShape(Rectangle())
        // Focus clavier — anneau distinct, superposable à la sélection.
        .overlay(focusRing)
        .overlay(alignment: .top)    { dropLine(visible: dropTarget == .insertAbove) }
        .overlay(alignment: .bottom) { dropLine(visible: dropTarget == .insertBelow) }
        .opacity(isDragging ? SlateOpacity.dragGhost : (isDisabled ? SlateOpacity.disabled : 1))
        .onHover { hovering in
            withAnimation(SlateMotion.standard(SlateMotion.fast, reduceMotion: reduceMotion)) {
                isHovering = hovering && !isDisabled
            }
        }
        .onTapGesture { onActivate?() }
        .focusable(!isDisabled)
        .focused($focused)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(selection == .none ? [] : [.isSelected])
        .accessibilityHint(isExpanded == nil ? "" : (isExpanded! ? "Replier le dossier" : "Déplier le dossier"))
    }

    // MARK: Fond

    private var background: some View {
        RoundedRectangle(cornerRadius: SlateRadius.s, style: .continuous)
            .fill(backgroundFill)
            .padding(.horizontal, SlateSpace.s)   // gouttière de la sidebar
    }

    private var backgroundFill: Color {
        if dropTarget == .onRow { return accent.subtle }
        switch selection {
        case .active:   return isPressed ? accent.selectionFillPressed : accent.selectionFill
        case .inactive: return SlateColors.stateSelectedInactive
        case .none:
            if isPressed { return SlateColors.statePressed }
            return isHovering ? SlateColors.stateHover : .clear
        }
    }

    private var foreground: Color {
        selection == .active ? accent.onAccent : SlateColors.textPrimary
    }

    // MARK: Contenu

    private var content: some View {
        HStack(spacing: SlateSpace.xs) {
            chevron
            Image(systemName: systemImage)
                .font(.system(size: SlateMetrics.iconS, weight: .medium))
                .foregroundStyle(selection == .active ? accent.onAccent : (iconTint ?? SlateColors.textSecondary))
                .frame(width: SlateMetrics.iconM)
                .accessibilityHidden(true)
            Text(title)
                .slateFont(.sidebarItem)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: SlateSpace.xs)
            if let badge {
                Text(badge)
                    .slateFont(.caption)
                    .tabularDigits()
                    .foregroundStyle(selection == .active ? accent.onAccent.opacity(0.8) : SlateColors.textTertiary)
            }
            accessory()
                .opacity(isHovering || selection != .none ? 1 : 0)   // révélé au survol
        }
        .padding(.horizontal, SlateSpace.s)
        .padding(.vertical, SlateSpace.xs)
        .padding(.leading, SlateSpace.s + CGFloat(level) * SlateMetrics.sidebarIndentStep)
    }

    @ViewBuilder private var chevron: some View {
        if let isExpanded {
            Button(action: { onToggleExpand?() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selection == .active ? accent.onAccent.opacity(0.9) : SlateColors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(SlateMotion.standard(SlateMotion.fast, reduceMotion: reduceMotion), value: isExpanded)
                    .frame(width: SlateMetrics.iconS, height: SlateMetrics.iconS)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        } else {
            Color.clear.frame(width: SlateMetrics.iconS, height: SlateMetrics.iconS)
        }
    }

    // MARK: Focus clavier & dépôt

    @ViewBuilder private var focusRing: some View {
        if focused || isFocused {
            RoundedRectangle(cornerRadius: SlateRadius.s, style: .continuous)
                .strokeBorder(accent.focusRing, lineWidth: SlateStroke.focusRingWidth)
                .padding(.horizontal, SlateSpace.s - SlateStroke.focusRingOffset)
                .transition(.opacity)
        }
    }

    @ViewBuilder private func dropLine(visible: Bool) -> some View {
        if visible {
            Rectangle()
                .fill(accent.color)
                .frame(height: 2)
                .overlay(alignment: .leading) {
                    Circle().stroke(accent.color, lineWidth: 2).frame(width: 6, height: 6)
                }
                .padding(.leading, SlateSpace.s + CGFloat(level) * SlateMetrics.sidebarIndentStep + SlateSpace.s)
                .padding(.trailing, SlateSpace.s)
        }
    }

    private var accessibilityLabel: String {
        var parts = [title]
        if let isExpanded { parts.append(isExpanded ? "dossier déplié" : "dossier plié") }
        if let badge { parts.append("\(badge) notes") }
        return parts.joined(separator: ", ")
    }
}

public extension SidebarRow where Accessory == EmptyView {
    init(title: String, systemImage: String, iconTint: Color? = nil, level: Int = 0,
         isExpanded: Bool? = nil, badge: String? = nil, isDisabled: Bool = false,
         selection: SlateRowSelection = .none, dropTarget: SlateDropTarget = .none,
         isDragging: Bool = false, onToggleExpand: (() -> Void)? = nil, onActivate: (() -> Void)? = nil) {
        self.init(title: title, systemImage: systemImage, iconTint: iconTint, level: level,
                  isExpanded: isExpanded, badge: badge, isDisabled: isDisabled,
                  accessory: { EmptyView() }, selection: selection, dropTarget: dropTarget,
                  isDragging: isDragging, onToggleExpand: onToggleExpand, onActivate: onActivate)
    }
}

// MARK: - En-tête de section

public struct SidebarSectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionSystemImage: String = "plus"
    @State private var isHovering = false

    public init(_ title: String, actionSystemImage: String = "plus", action: (() -> Void)? = nil) {
        self.title = title; self.action = action; self.actionSystemImage = actionSystemImage
    }

    public var body: some View {
        HStack {
            Text(title)
                .slateFont(.sidebarSectionHeader)
                .foregroundStyle(SlateColors.textSecondary)
            Spacer()
            if let action {
                Button(action: action) { Image(systemName: actionSystemImage) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SlateColors.textTertiary)
                    .opacity(isHovering ? 1 : 0)
                    .accessibilityLabel("Ajouter dans \(title)")
            }
        }
        .padding(.horizontal, SlateSpace.l)
        .padding(.top, SlateSpace.m)
        .padding(.bottom, SlateSpace.xs)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(.isHeader)
    }
}

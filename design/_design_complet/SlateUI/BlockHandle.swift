//  BlockHandle.swift — SlateUI
//  Chrome de bloc révélé au survol : bouton + (insérer) puis poignée ⋮⋮ (drag + menu).
//  Composant réutilisable par tous les types de blocs (E4, E6, E7).

import SwiftUI

// MARK: - États d'un bloc

public enum SlateBlockState: Equatable {
    /// Repos : aucun chrome, aucun aplat.
    case normal
    /// Souris dans la zone du bloc → chrome visible, pas d'aplat.
    case hovered
    /// Édition : le caret est dans ce bloc. Chrome visible.
    case focused
    /// Bloc sélectionné en entier (Échap, ⌘A, clic sur la poignée) → `block.selected.bg`.
    case selected
    /// Focus clavier de navigation (Tab / VoiceOver) — distinct de `.selected` :
    /// contour `focusRing`, aucun aplat.
    case keyboardFocused

    var showsChrome: Bool {
        self == .hovered || self == .focused || self == .selected || self == .keyboardFocused
    }
    var showsSelectionFill: Bool { self == .selected }
    var showsFocusRing: Bool { self == .keyboardFocused }
}

// MARK: - Position d'une sélection multi-blocs (coins arrondis)

public enum SlateBlockRangePosition: Equatable {
    case single, first, middle, last
    /// L'aplat comble le `blockSpacing` entre deux blocs voisins pour se lire comme une seule zone.
    var topRadius: CGFloat { self == .single || self == .first ? SlateRadius.m : 0 }
    var bottomRadius: CGFloat { self == .single || self == .last ? SlateRadius.m : 0 }
    var extendsDown: Bool { self == .first || self == .middle }
}

// MARK: - Poignée + bouton d'insertion

public struct BlockHandle: View {
    /// Chrome visible ? (piloté par l'état du bloc, animé en `motion.duration.fast`)
    let isVisible: Bool
    var onInsert: () -> Void = {}
    var onMenu: () -> Void = {}
    /// Fourni par le parent : identifiant de bloc pour le `draggable`.
    var dragPayload: String = ""

    @Environment(\.slateAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isVisible: Bool,
                dragPayload: String = "",
                onInsert: @escaping () -> Void = {},
                onMenu: @escaping () -> Void = {}) {
        self.isVisible = isVisible
        self.dragPayload = dragPayload
        self.onInsert = onInsert
        self.onMenu = onMenu
    }

    public var body: some View {
        HStack(spacing: SlateSpace.xs) {
            GlyphButton(systemName: "plus", help: "Insérer un bloc en dessous", action: onInsert)
                .accessibilityLabel("Insérer un bloc")

            GlyphButton(systemName: "line.3.horizontal", help: "Glisser pour déplacer · cliquer pour le menu",
                        action: onMenu)
                .accessibilityLabel("Options du bloc")
                .draggable(dragPayload) {
                    // Fantôme de drag : `opacity.dragGhost`, ombre `elevation.high`.
                    RoundedRectangle(cornerRadius: SlateRadius.m)
                        .fill(SlateColors.surfacePrimary)
                        .frame(width: 220, height: 28)
                        .opacity(SlateOpacity.dragGhost)
                        .slateShadow(.high)
                }
        }
        .frame(width: SlateMetrics.handleSize * 2 + SlateSpace.xs,
               height: SlateMetrics.handleSize, alignment: .trailing)
        .opacity(isVisible ? 1 : 0)
        .animation(SlateMotion.standard(SlateMotion.fast, reduceMotion: reduceMotion), value: isVisible)
        // Le chrome reste hors du flux : il n'affecte jamais la mise en page du texte.
        .allowsHitTesting(isVisible)
    }
}

// MARK: - Bouton glyphe 18 pt (handle.size)

private struct GlyphButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: SlateMetrics.iconS - 2, weight: .medium))
                .foregroundStyle(isHovering ? SlateEditorColors.handleHover : SlateEditorColors.handleIdle)
                .frame(width: SlateMetrics.handleSize, height: SlateMetrics.handleSize)
                .background(
                    RoundedRectangle(cornerRadius: SlateRadius.s)
                        .fill(isHovering ? SlateEditorColors.handleBgHover : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(SlateMotion.standard(SlateMotion.fast, reduceMotion: reduceMotion)) {
                isHovering = hovering
            }
        }
        .help(help)
        // Cible de clic élargie à 24 pt sans changer la métrique visuelle (18 pt).
        .padding(SlateSpace.xs)
        .padding(-SlateSpace.xs)
    }
}

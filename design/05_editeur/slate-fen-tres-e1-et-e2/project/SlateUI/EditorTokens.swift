//  EditorTokens.swift — SlateUI
//  §16 de design/tokens.md : tokens spécifiques à l'éditeur & aux blocs.
//  Rien de codé en dur ailleurs : E4/E6/E7 lisent uniquement ce fichier + Tokens.swift.

import SwiftUI
import AppKit

// MARK: - §16 — Couleurs de l'éditeur

public enum SlateEditorColors {

    // Blocs
    /// `block.selected.bg` — aplat d'un bloc (ou d'une plage de blocs) sélectionné.
    public static let blockSelected = Color.slate(light: NSColor(hex: 0x007AFF, alpha: 0.12),
                                                 dark:  NSColor(hex: 0x0A84FF, alpha: 0.20),
                                                 lightHC: NSColor(hex: 0x007AFF, alpha: 0.22),
                                                 darkHC:  NSColor(hex: 0x0A84FF, alpha: 0.32))
    /// `code.block.bg` — réservé à E7, exposé ici car c'est un token §16.
    public static let codeBlockBg = Color.slate(light: NSColor(hex: 0xF5F5F7), dark: NSColor(hex: 0x2A2A2C))
    /// `quote.barColor`
    public static let quoteBar    = Color.slate(light: NSColor(hex: 0xD1D1D6), dark: NSColor(hex: 0x48484A))
    /// `divider.color` = `separator`
    public static let divider     = SlateColors.separator

    // Chrome de bloc (poignée ⋮⋮ + bouton +) — pas de token dédié dans §16 :
    // dérivé de §2 texte + §3 états, comme le reste du chrome UI.
    public static let handleIdle    = SlateColors.textTertiary
    public static let handleHover   = SlateColors.textSecondary
    public static let handleBgHover = SlateColors.stateHover
    public static let handleBgPress = SlateColors.statePressed
}

public extension SlateAccent {
    /// `block.dropIndicator` — ligne d'insertion pendant un drag de bloc.
    var blockDropIndicator: Color { color }
    /// Curseur de saisie (`insertionPoint` macOS = couleur d'accent).
    var caret: Color { color }
}

// MARK: - §16 — Métriques de l'éditeur

public enum SlateEditorMetrics {
    /// `editor.maxContentWidth`
    public static let maxContentWidth: CGFloat = SlateMetrics.editorMaxContentWidth   // 720
    /// `editor.blockSpacing`
    public static let blockSpacing: CGFloat = SlateMetrics.editorBlockSpacing         // 4
    /// `editor.paragraphLineHeight` (déjà porté par `SlateTextStyle.body`)
    public static let paragraphLineHeight: CGFloat = 1.5

    /// Gouttière réservée au chrome de bloc, à gauche de la colonne de texte.
    /// 2 × `handle.size` (18) + `space.xs` (4) + `space.s` (8) de dégagement = 48.
    public static let gutter: CGFloat = SlateMetrics.handleSize * 2 + SlateSpace.xs + SlateSpace.s
    /// Débord horizontal de l'aplat de sélection de bloc, de part et d'autre du texte.
    public static let selectionBleed: CGFloat = SlateSpace.s          // 8
    /// Épaisseur du caret et de la ligne d'insertion.
    public static let caretWidth: CGFloat = 2
    public static let dropIndicatorHeight: CGFloat = 2

    /// Respiration verticale de la colonne.
    public static let contentTopPadding: CGFloat = SlateSpace.xxl     // 32 (sans couverture)
    public static let contentBottomPadding: CGFloat = 240             // zone de clic « nouveau bloc »
    public static let headerToBodySpacing: CGFloat = SlateSpace.xl    // 24
    public static let coverHeight: CGFloat = 200
    public static let coverHeightCompact: CGFloat = 120
    public static let iconSize: CGFloat = 64
    /// Chevauchement de l'icône sur la couverture.
    public static let iconOverlap: CGFloat = SlateSpace.xxl           // 32
    public static let toolbarHeight: CGFloat = SlateMetrics.controlL + SlateSpace.s  // 44
}

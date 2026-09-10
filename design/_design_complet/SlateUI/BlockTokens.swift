//  BlockTokens.swift — SlateUI
//  Compléments §16 requis par la planche P1 (formatage & blocs).
//  Chaque valeur est mesurée composée sur le fond réel du bloc, pas sur bg.editor nu.

import SwiftUI
import AppKit

// MARK: - §2 (correction) — placeholder lisible

public enum SlateTextFix {
    /// `text.placeholder` corrigé : 0.25 donnait 1,83:1 sur `bg.editor` clair.
    /// 0.55 / 0.60 → 4,76:1 et 6,86:1. `text.disabled` reste à 0.25 (pas d'obligation AA).
    public static let placeholder = Color.slate(light: .black(0.55), dark: .white(0.60),
                                                lightHC: .black(0.70), darkHC: .white(0.78))
}

// MARK: - §16 bis — Callouts

public enum SlateCalloutVariant: String, CaseIterable, Identifiable, Codable {
    case neutral, info, warning, success
    public var id: String { rawValue }

    /// Fond du callout. Les variantes sont des aplats opaques dérivés des `semantic.*`
    /// composés à 12 % (clair) / 18 % (sombre) — figés pour rester mesurables.
    public var background: Color {
        switch self {
        case .neutral: SlateColors.surfaceSecondary                                    // callout.bg
        case .info:    .slate(light: NSColor(hex: 0xE5F1FF), dark: NSColor(hex: 0x1B2A3A))
        case .warning: .slate(light: NSColor(hex: 0xFFF4E5), dark: NSColor(hex: 0x3A2E1A))
        case .success: .slate(light: NSColor(hex: 0xEAF9EE), dark: NSColor(hex: 0x1F3D27))
        }
    }

    /// `callout.border`
    public var border: Color { .slate(light: .black(0.08), dark: .white(0.10)) }

    /// Couleur du libellé de variante ET de l'icône.
    /// Les `semantic.*` bruts tombent à 2,0–3,5:1 sur ces fonds : ils sont écartés pour du texte.
    public var labelColor: Color {
        switch self {
        case .neutral: SlateColors.textSecondary
        case .info:    .slate(light: NSColor(hex: 0x05509E), dark: NSColor(hex: 0x6CB6FF)) // 6,93 · 6,04
        case .warning: .slate(light: NSColor(hex: 0x9A5700), dark: NSColor(hex: 0xFF9F0A)) // 5,17 · 5,83
        case .success: .slate(light: NSColor(hex: 0x1E7A34), dark: NSColor(hex: 0x30D158)) // 4,96 · 5,94
        }
    }

    /// Libellé textuel : l'information n'est jamais portée par la seule couleur.
    public var label: String? {
        switch self {
        case .neutral: nil
        case .info: "Information"
        case .warning: "Attention"
        case .success: "Succès"
        }
    }

    public var symbol: String {
        switch self {
        case .neutral: "pin.fill"
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .success: "checkmark.circle"
        }
    }
}

// MARK: - §16 ter — Coloration syntaxique

public enum SlateSyntaxToken: String, CaseIterable {
    case plain, keyword, string, number, type, comment

    /// Mesuré sur `code.block.bg` (#F5F5F7 / #2A2A2C).
    public var color: Color {
        switch self {
        case .plain:   SlateColors.textPrimary                                          // 15,1 · 13,9
        case .keyword: .slate(light: NSColor(hex: 0xAF00DB), dark: NSColor(hex: 0xFF7AB2)) // 5,01 · 5,93
        case .string:  .slate(light: NSColor(hex: 0xA31515), dark: NSColor(hex: 0xFF8170)) // 7,20 · 5,89
        case .number:  .slate(light: NSColor(hex: 0x0B6E99), dark: NSColor(hex: 0xD9C97C)) // 5,20 · 8,90
        case .type:    .slate(light: NSColor(hex: 0x6F42C1), dark: NSColor(hex: 0xB281F0)) // 5,97 · 4,98
        case .comment: .slate(light: NSColor(hex: 0x5A626B), dark: NSColor(hex: 0x96A3AE)) // 5,67 · 5,57
        }
    }
}

// MARK: - §16 — Compléments blocs

public extension SlateEditorColors {
    /// `code.inline.bg` / `code.inline.text` — 5,28:1 clair, 5,03:1 sombre.
    static let codeInlineBg   = Color.slate(light: .black(0.06), dark: .white(0.10))
    static let codeInlineText = Color.slate(light: NSColor(hex: 0xBF2600), dark: NSColor(hex: 0xFF7B72))
    /// `quote.text`
    static let quoteText  = Color.slate(light: .black(0.65), dark: .white(0.65))
    /// `table.header.bg` / `table.border` / `table.rowStripe`
    static let tableHeaderBg = SlateColors.surfaceSecondary
    static let tableBorder   = SlateColors.separator
    static let tableRowStripe = Color.slate(light: .black(0.02), dark: .white(0.03))
    /// `todo.checkbox.border`
    static let todoCheckboxBorder = Color.slate(light: .black(0.30), dark: .white(0.35))
}

// MARK: - Métriques de blocs décorés

public enum SlateBlockMetrics {
    /// Marge verticale d'un bloc décoré (code, citation, callout, tableau, divider),
    /// au lieu des 4 pt de `editor.blockSpacing` des paragraphes.
    public static let decoratedSpacing: CGFloat = SlateSpace.s
    /// Indentation par niveau de liste (⇥ / ⇧⇥).
    public static let listIndent: CGFloat = SlateSpace.xl        // 24
    /// Colonne du marqueur (puce, numéro, case).
    public static let markerWidth: CGFloat = SlateMetrics.handleSize   // 18
    /// Cible de clic d'une case à cocher, plus grande que le glyphe.
    public static let checkboxHitSize: CGFloat = SlateMetrics.controlM // 28
    /// `column.gap` et largeur minimale d'une colonne.
    public static let columnGap: CGFloat = SlateSpace.xl         // 24
    public static let columnMinWidth: CGFloat = 120
    public static let columnMaxCount = 4
    /// En dessous, les colonnes s'empilent (idem à partir de `.accessibility1`).
    public static let columnStackThreshold: CGFloat = 560
    /// Largeur de la poignée de séparateur de colonnes au survol.
    public static let columnResizerWidth: CGFloat = 4
    /// Barre latérale de citation.
    public static let quoteBarWidth: CGFloat = 3
    /// Hauteur de la cible de sélection d'un divider.
    public static let dividerHitHeight: CGFloat = SlateSpace.xl  // 24
}

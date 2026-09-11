import SwiftUI

/// Coloration syntaxique du bloc de code (design/tokens.md §16 ter, artboard E de
/// `Slate P1 - Formatage & blocs.dc.html`, Phase 8). Mesuree sur `code.block.bg`
/// (`SlateColor.codeBlockBackground`, #F5F5F7 / #2A2A2C), pas sur `bg.editor` nu.
public enum SlateSyntaxToken: String, CaseIterable, Sendable {
    case plain
    case keyword
    case string
    case number
    case type
    case comment

    /// RGB brut clair, expose pour les tests de contraste (meme motif que
    /// `SlateCalloutVariant`) : `plain` reprend `text.primary` (noir 85%).
    var lightRGB: SlateRGB {
        switch self {
        case .plain: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85)
        case .keyword: SlateRGB(hex: "#AF00DB") ?? .black
        case .string: SlateRGB(hex: "#A31515") ?? .black
        case .number: SlateRGB(hex: "#0B6E99") ?? .black
        case .type: SlateRGB(hex: "#6F42C1") ?? .black
        case .comment: SlateRGB(hex: "#5A626B") ?? .black
        }
    }

    var darkRGB: SlateRGB {
        switch self {
        case .plain: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.85)
        case .keyword: SlateRGB(hex: "#FF7AB2") ?? .white
        case .string: SlateRGB(hex: "#FF8170") ?? .white
        case .number: SlateRGB(hex: "#D9C97C") ?? .white
        case .type: SlateRGB(hex: "#B281F0") ?? .white
        case .comment: SlateRGB(hex: "#96A3AE") ?? .white
        }
    }

    /// Couleur adaptative clair/sombre, pour l'utilisation directe dans une vue.
    public var color: Color { slateAdaptiveColor(light: lightRGB, dark: darkRGB) }
}

import SwiftUI

/// Tokens de couleur du formatage inline (design/tokens.md §6 "Surlignage de texte" et
/// artboard `design/_design_complet/Slate P1 - Formatage & blocs.dc.html`, section B
/// "Palette de surlignage & couleur de texte", Phase 7).
///
/// `SlateUI` ne depend PAS de `SlateModel` (voir `Package.swift` : aucune dependance
/// declaree) alors que `SlateModel.SlateHighlightColor` (voir
/// `SlateInlineAttributes.swift`) porte la couleur de surlignage sous forme neutre,
/// un simple `String` (ex: `"yellow"`). La resolution en `Color` concrete est donc
/// exposee ICI par IDENTIFIANT (`String`), pas par un type importe de `SlateModel` :
/// c'est a l'appelant (`SlateEditor`, qui depend des deux packages) de faire le pont
/// entre `SlateHighlightColor.value` et `SlateColor.highlightBackground(forIdentifier:)`.
public enum SlateHighlightToken: String, CaseIterable, Sendable {
    case yellow
    case green
    case blue
    case pink
    case red
    case gray

    var lightRGB: SlateRGB {
        switch self {
        case .yellow: SlateRGB(hex: "#FFF3B0") ?? .white
        case .green: SlateRGB(hex: "#D7F0D0") ?? .white
        case .blue: SlateRGB(hex: "#D0E4FF") ?? .white
        case .pink: SlateRGB(hex: "#FBD5E4") ?? .white
        case .red: SlateRGB(hex: "#FFD6D2") ?? .white
        case .gray: SlateRGB(hex: "#E3E3E6") ?? .white
        }
    }

    var darkRGB: SlateRGB {
        switch self {
        case .yellow: SlateRGB(hex: "#4D4A2E") ?? .black
        case .green: SlateRGB(hex: "#2E4632") ?? .black
        case .blue: SlateRGB(hex: "#2C3E52") ?? .black
        case .pink: SlateRGB(hex: "#4A2E3B") ?? .black
        case .red: SlateRGB(hex: "#4D2E2C") ?? .black
        case .gray: SlateRGB(hex: "#3A3A3C") ?? .black
        }
    }

    /// Aplat de surlignage adaptatif clair/sombre. Le texte pose par-dessus reste
    /// toujours `text.primary` (jamais une couleur derivee du surlignage), voir
    /// l'artboard B : "texte = text.primary par-dessus".
    public var background: Color {
        slateAdaptiveColor(light: lightRGB, dark: darkRGB)
    }
}

/// Tokens de couleur de TEXTE inline (artboard P1 B, deuxieme rangee du popover :
/// "Couleur du texte"). Distincts des couleurs vives de la palette d'accents (§7,
/// `SlateFolderColor`) : ce sont des teintes assombries en clair / eclaircies en
/// sombre, mesurees pour rester >= 4,5:1 sur `bg.editor`. Les valeurs vives de §7 ne
/// sont valides que pour les aplats et les icones, jamais pour du texte (artboard B).
public enum SlateTextColorToken: String, CaseIterable, Sendable {
    /// Pas de teinte : reprend `text.primary` (premiere pastille du popover, cochee par
    /// defaut).
    case primary
    case blue
    case green
    case orange
    case red
    case purple
    case gray

    var lightRGB: SlateRGB {
        switch self {
        case .primary: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85)
        case .blue: SlateRGB(hex: "#05509E") ?? .black
        case .green: SlateRGB(hex: "#1E7A34") ?? .black
        case .orange: SlateRGB(hex: "#9A5700") ?? .black
        case .red: SlateRGB(hex: "#B3261E") ?? .black
        case .purple: SlateRGB(hex: "#7B3AA8") ?? .black
        case .gray: SlateRGB(hex: "#5A626B") ?? .black
        }
    }

    var darkRGB: SlateRGB {
        switch self {
        case .primary: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.85)
        case .blue: SlateRGB(hex: "#6CB6FF") ?? .white
        case .green: SlateRGB(hex: "#5FD98A") ?? .white
        case .orange: SlateRGB(hex: "#FFB84D") ?? .white
        case .red: SlateRGB(hex: "#FF8A82") ?? .white
        case .purple: SlateRGB(hex: "#CB9AF5") ?? .white
        case .gray: SlateRGB(hex: "#A8B0B8") ?? .white
        }
    }

    /// Couleur de texte adaptative clair/sombre.
    public var foreground: Color {
        slateAdaptiveColor(light: lightRGB, dark: darkRGB)
    }
}

public extension SlateColor {
    /// Resout un identifiant neutre de surlignage (typiquement
    /// `SlateHighlightColor.value` cote `SlateModel`, ex: `"yellow"`) en couleur de
    /// fond adaptative. `nil` si l'identifiant ne correspond a aucun des 6 tokens de
    /// §6 (ex: une couleur hex directe -- non geree en Phase 7, la palette de l'artboard
    /// B ne propose que ces 6 teintes nommees).
    static func highlightBackground(forIdentifier identifier: String) -> Color? {
        SlateHighlightToken(rawValue: identifier)?.background
    }

    /// Resout un identifiant neutre de couleur de texte inline en couleur adaptative.
    /// `nil` si l'identifiant ne correspond a aucun des 7 tokens de la palette
    /// "Couleur du texte" (artboard P1 B).
    static func textColorBackground(forIdentifier identifier: String) -> Color? {
        SlateTextColorToken(rawValue: identifier)?.foreground
    }

    /// `code.inline.bg`. Fond du code inline (distinct de `code.block.bg`, reserve au
    /// bloc de code).
    static let codeInlineBackground = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.06),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.10)
    )

    /// `code.inline.text`. Texte du code inline. Artboard D : 5,28:1 sur `code.inline.bg`
    /// compose sur `bg.editor`, AA.
    static let codeInlineText = slateAdaptiveColor(
        light: SlateRGB(hex: "#BF2600") ?? .black,
        dark: SlateRGB(hex: "#FF7B72") ?? .white
    )
}

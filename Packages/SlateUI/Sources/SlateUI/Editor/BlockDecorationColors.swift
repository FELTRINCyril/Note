import SwiftUI

/// Couleurs des blocs "decores" qui ne sont pas deja couvertes par `EditorColors.swift`
/// (design/tokens.md §16, artboards F/G/H de `Slate P1 - Formatage & blocs.dc.html`,
/// Phase 8).
///
/// `codeBlockBackground`, `quoteBarColor` et `dividerColor` existent deja depuis les
/// Phases 6/7 (`Editor/EditorColors.swift`) : reutilises tels quels, pas redefinis ici.
public extension SlateColor {
    /// `quote.text`. Corps d'une citation, artboard F : "le texte a 65 % - 6,98:1 sur
    /// blanc, 7,82:1 sur `#1C1C1E`".
    static let quoteText = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.65),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.65)
    )

    /// `callout.border`. Liseré commun aux 4 variantes de callout (artboard F).
    static let calloutBorder = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.08),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.10)
    )

    /// `todo.checkbox.border`. Case a cocher non cochee (artboard G).
    static let todoCheckboxBorder = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.30),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.35)
    )

    /// `todo.text.done` = `text.tertiary` (design/tokens.md §16) : alias nomme, pas une
    /// nouvelle teinte. Le barre (`strikethrough`) est appliquee par la vue, pas ce token.
    static let todoTextDone = textTertiary

    /// `table.header.bg`. Meme valeur que `surface.secondary` (artboard H : `#F2F2F5` /
    /// `#2C2C2E`) : alias nomme pour la tracabilite avec le token §16, pas une nouvelle
    /// teinte.
    static let tableHeaderBg = surfaceSecondary

    /// `table.border` = `separator` (design/tokens.md §16) : alias nomme.
    static let tableBorder = separator

    /// `table.rowStripe`. Ligne alternee optionnelle (artboard H).
    static let tableRowStripe = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.02),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.03)
    )
}

//  Tokens.swift — SlateUI
//  Source de vérité : design/tokens.md. Aucune couleur / taille / durée en dur ailleurs.
//  macOS 15, SwiftUI.

import SwiftUI
import AppKit

// MARK: - Utilitaires couleur dynamique (clair / sombre / Increase Contrast)

public extension NSColor {
    /// Couleur dynamique résolue par apparence, avec variantes optionnelles
    /// pour « Augmenter le contraste » (Réglages > Accessibilité > Moniteur).
    static func slateDynamic(light: NSColor,
                             dark: NSColor,
                             lightHC: NSColor? = nil,
                             darkHC: NSColor? = nil) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua,
                                                     .accessibilityHighContrastAqua,
                                                     .accessibilityHighContrastDarkAqua])
                .map { $0 == .darkAqua || $0 == .accessibilityHighContrastDarkAqua } ?? false
            let isHC = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            switch (isDark, isHC) {
            case (false, false): return light
            case (false, true):  return lightHC ?? light
            case (true,  false): return dark
            case (true,  true):  return darkHC ?? dark
            }
        }
    }

    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
    static func white(_ a: CGFloat) -> NSColor { NSColor(srgbRed: 1, green: 1, blue: 1, alpha: a) }
    static func black(_ a: CGFloat) -> NSColor { NSColor(srgbRed: 0, green: 0, blue: 0, alpha: a) }
}

public extension Color {
    static func slate(light: NSColor, dark: NSColor,
                      lightHC: NSColor? = nil, darkHC: NSColor? = nil) -> Color {
        Color(nsColor: .slateDynamic(light: light, dark: dark, lightHC: lightHC, darkHC: darkHC))
    }
}

// MARK: - §1 Fonds & surfaces · §2 Texte · §4 Sémantiques · §5 Bordures

public enum SlateColors {

    // §1 — Fonds & surfaces
    public static let bgWindow      = Color.slate(light: NSColor(hex: 0xECECEC), dark: NSColor(hex: 0x1E1E1E))
    /// Base opaque derrière le matériau `.sidebar` (utilisée si Reduce Transparency est actif).
    public static let bgSidebarBase = Color.slate(light: NSColor(hex: 0xF2F2F5), dark: NSColor(hex: 0x232326))
    public static let bgList        = Color.slate(light: NSColor(hex: 0xFFFFFF), dark: NSColor(hex: 0x1E1E1E))
    public static let bgEditor      = Color.slate(light: NSColor(hex: 0xFFFFFF), dark: NSColor(hex: 0x1C1C1E))
    public static let surfacePrimary   = Color.slate(light: NSColor(hex: 0xFFFFFF), dark: NSColor(hex: 0x2A2A2C))
    public static let surfaceSecondary = Color.slate(light: NSColor(hex: 0xF2F2F5), dark: NSColor(hex: 0x2C2C2E))
    public static let surfaceTertiary  = Color.slate(light: NSColor(hex: 0xE5E5EA), dark: NSColor(hex: 0x3A3A3C))
    public static let overlayScrim  = Color.slate(light: .black(0.20), dark: .black(0.45))

    // §2 — Texte (variantes HC renforcées pour garder AA/AAA)
    public static let textPrimary     = Color.slate(light: .black(0.85), dark: .white(0.85),
                                                    lightHC: .black(1.0), darkHC: .white(1.0))
    public static let textSecondary   = Color.slate(light: .black(0.50), dark: .white(0.55),
                                                    lightHC: .black(0.72), darkHC: .white(0.78))
    public static let textTertiary    = Color.slate(light: .black(0.26), dark: .white(0.26),
                                                    lightHC: .black(0.55), darkHC: .white(0.60))
    public static let textPlaceholder = Color.slate(light: .black(0.25), dark: .white(0.25),
                                                    lightHC: .black(0.52), darkHC: .white(0.58))
    public static let textDisabled    = Color.slate(light: .black(0.25), dark: .white(0.25))
    public static let textOnAccent    = Color.white
    public static let textInverse     = Color.slate(light: .white(1), dark: .black(1))

    // §4 — Sémantiques
    public static let error   = Color.slate(light: NSColor(hex: 0xFF3B30), dark: NSColor(hex: 0xFF453A))
    public static let warning = Color.slate(light: NSColor(hex: 0xFF9500), dark: NSColor(hex: 0xFF9F0A))
    public static let success = Color.slate(light: NSColor(hex: 0x34C759), dark: NSColor(hex: 0x30D158))
    public static let info    = Color.slate(light: NSColor(hex: 0x007AFF), dark: NSColor(hex: 0x0A84FF))

    // §5 — Séparateurs & bordures
    public static let separator     = Color.slate(light: .black(0.10), dark: .white(0.15),
                                                  lightHC: .black(0.28), darkHC: .white(0.35))
    public static let borderDefault = Color.slate(light: .black(0.12), dark: .white(0.15),
                                                  lightHC: .black(0.32), darkHC: .white(0.38))
    public static let borderStrong  = Color.slate(light: .black(0.22), dark: .white(0.28))

    // §3 — États génériques (indépendants de l'accent)
    public static let stateHover            = Color.slate(light: .black(0.05), dark: .white(0.07))
    public static let statePressed          = Color.slate(light: .black(0.10), dark: .white(0.12))
    public static let stateSelectedInactive = Color.slate(light: .black(0.10), dark: .white(0.13),
                                                          lightHC: .black(0.18), darkHC: .white(0.22))
}

// MARK: - §3 & §7 — Accent personnalisable

/// Palette d'accents système macOS (§7). Chaque cas porte ses paires clair/sombre.
public enum SlateAccent: String, CaseIterable, Identifiable, Codable {
    case blue, purple, pink, red, orange, yellow, green, graphite
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .blue: "Bleu"; case .purple: "Violet"; case .pink: "Rose"; case .red: "Rouge"
        case .orange: "Orange"; case .yellow: "Jaune"; case .green: "Vert"; case .graphite: "Graphite"
        }
    }

    var lightHex: UInt32 {
        switch self {
        case .blue: 0x007AFF; case .purple: 0xAF52DE; case .pink: 0xFF2D55; case .red: 0xFF3B30
        case .orange: 0xFF9500; case .yellow: 0xFFCC00; case .green: 0x34C759; case .graphite: 0x8E8E93
        }
    }
    var darkHex: UInt32 {
        switch self {
        case .blue: 0x0A84FF; case .purple: 0xBF5AF2; case .pink: 0xFF375F; case .red: 0xFF453A
        case .orange: 0xFF9F0A; case .yellow: 0xFFD60A; case .green: 0x30D158; case .graphite: 0x98989D
        }
    }

    // Dérivations sans casser les contrastes : hover = -8 % de luminosité, pressed = -18 %.
    public var color: Color        { .slate(light: NSColor(hex: lightHex), dark: NSColor(hex: darkHex)) }
    public var hover: Color        { .slate(light: NSColor(hex: lightHex).adjusted(brightness: -0.08),
                                            dark: NSColor(hex: darkHex).adjusted(brightness: 0.12)) }
    public var pressed: Color      { .slate(light: NSColor(hex: lightHex).adjusted(brightness: -0.18),
                                            dark: NSColor(hex: darkHex).adjusted(brightness: -0.10)) }
    public var subtle: Color       { .slate(light: NSColor(hex: lightHex, alpha: 0.12),
                                            dark: NSColor(hex: darkHex, alpha: 0.22)) }
    public var selectedText: Color { .slate(light: NSColor(hex: lightHex, alpha: 0.28),
                                            dark: NSColor(hex: darkHex, alpha: 0.35)) }
    public var focusRing: Color    { .slate(light: NSColor(hex: lightHex, alpha: 0.60),
                                            dark: NSColor(hex: darkHex, alpha: 0.65)) }

    /// Texte lisible sur un aplat d'accent : blanc partout sauf jaune (AA impossible en blanc).
    public var onAccent: Color {
        switch self {
        case .yellow: Color.slate(light: .black(0.88), dark: .black(0.88))
        default: SlateColors.textOnAccent
        }
    }
}

private extension NSColor {
    func adjusted(brightness delta: CGFloat) -> NSColor {
        guard let c = usingColorSpace(.sRGB) else { return self }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: s, brightness: min(max(b + delta, 0), 1), alpha: a)
    }
}

/// Accent courant injecté dans l'environnement (personnalisable, cf. E11 / workspace E15).
private struct SlateAccentKey: EnvironmentKey { static let defaultValue: SlateAccent = .blue }
public extension EnvironmentValues {
    var slateAccent: SlateAccent {
        get { self[SlateAccentKey.self] }
        set { self[SlateAccentKey.self] = newValue }
    }
}

// MARK: - §9 Typographie (Dynamic Type via @ScaledMetric)

public enum SlateTextStyle {
    case titleNote, titleSecondary, subtitle
    case h1, h2, h3, h4, h5, h6
    case body, bodyEmphasis, mono, quote, callout, caption, label
    case sidebarItem, sidebarSectionHeader, listTitle, listSnippet

    var size: CGFloat {
        switch self {
        case .titleNote: 28; case .titleSecondary: 22; case .subtitle: 17
        case .h1: 26; case .h2: 22; case .h3: 20; case .h4: 17; case .h5: 15; case .h6: 13
        case .body, .bodyEmphasis, .quote: 15
        case .mono: 13; case .callout: 14; case .caption: 12; case .label: 13
        case .sidebarItem: 13; case .sidebarSectionHeader: 11
        case .listTitle: 14; case .listSnippet: 13
        }
    }
    var weight: Font.Weight {
        switch self {
        case .titleNote, .titleSecondary, .h1: .bold
        case .h2, .h3, .h4, .h5, .h6, .bodyEmphasis, .listTitle: .semibold
        case .sidebarSectionHeader: .semibold
        default: .regular
        }
    }
    var lineHeightMultiple: CGFloat {
        switch self {
        case .titleNote: 1.15; case .titleSecondary, .h1: 1.2; case .subtitle, .h3, .h4: 1.3
        case .h2: 1.25; case .h5: 1.35; case .h6: 1.4
        case .body, .bodyEmphasis, .quote: 1.5; case .mono, .callout: 1.45
        case .caption: 1.35; case .label, .sidebarItem, .listTitle, .sidebarSectionHeader: 1.3
        case .listSnippet: 1.35
        }
    }
    /// Style système de référence pour la mise à l'échelle Dynamic Type.
    var relativeTo: Font.TextStyle {
        switch self {
        case .titleNote: .largeTitle; case .titleSecondary, .h1: .title
        case .h2: .title2; case .h3: .title3; case .subtitle, .h4: .headline
        case .caption, .sidebarSectionHeader: .caption
        default: .body
        }
    }
    var design: Font.Design { self == .mono ? .monospaced : .default }
    var italic: Bool { self == .quote }
}

/// Applique police + interligne + scaling Dynamic Type.
public struct SlateFontModifier: ViewModifier {
    let style: SlateTextStyle
    @ScaledMetric private var scale: CGFloat

    public init(_ style: SlateTextStyle) {
        self.style = style
        _scale = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    public func body(content: Content) -> some View {
        content
            .font(.system(size: scale, weight: style.weight, design: style.design)
                    .italic(style.italic))
            .lineSpacing(scale * (style.lineHeightMultiple - 1))
            .kerning(style == .sidebarSectionHeader ? 0.4 : 0)
            .textCase(style == .sidebarSectionHeader ? .uppercase : nil)
    }
}

public extension View {
    func slateFont(_ style: SlateTextStyle) -> some View { modifier(SlateFontModifier(style)) }
    /// Chiffres tabulaires (cellules de base de données, calculs).
    func tabularDigits() -> some View { monospacedDigit() }
}

// MARK: - §10–§15 — Espacements, rayons, traits, ombres, opacités, métriques

public enum SlateSpace {
    public static let xxs: CGFloat = 2, xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12
    public static let l: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32, xxxl: CGFloat = 48
}

public enum SlateRadius {
    public static let s: CGFloat = 6, m: CGFloat = 8, l: CGFloat = 12, full: CGFloat = 999
}

public enum SlateStroke {
    public static let hairline: CGFloat = 1
    public static let regular: CGFloat = 1.5
    public static let focusRingWidth: CGFloat = 3
    public static let focusRingOffset: CGFloat = 1
}

public enum SlateElevation {
    case low, medium, high
    var y: CGFloat { switch self { case .low: 1; case .medium: 4; case .high: 10 } }
    var blur: CGFloat { switch self { case .low: 3; case .medium: 12; case .high: 30 } }
    var color: Color {
        switch self {
        case .low:    .slate(light: .black(0.08), dark: .black(0.30))
        case .medium: .slate(light: .black(0.12), dark: .black(0.40))
        case .high:   .slate(light: .black(0.20), dark: .black(0.55))
        }
    }
}
public extension View {
    func slateShadow(_ e: SlateElevation) -> some View {
        shadow(color: e.color, radius: e.blur / 2, x: 0, y: e.y)
    }
}

public enum SlateOpacity {
    public static let disabled: Double = 0.4
    public static let hoverOverlay: Double = 0.06
    public static let dragGhost: Double = 0.6
}

public enum SlateMetrics {
    public static let iconS: CGFloat = 14, iconM: CGFloat = 16, iconL: CGFloat = 20
    public static let controlS: CGFloat = 22, controlM: CGFloat = 28, controlL: CGFloat = 36
    public static let sidebarRowHeight: CGFloat = 28
    public static let noteCellHeight: CGFloat = 64
    public static let handleSize: CGFloat = 18
    public static let checkboxSize: CGFloat = 18
    // §17
    public static let sidebarIndentStep: CGFloat = 16
    // §16
    public static let editorMaxContentWidth: CGFloat = 720
    public static let editorBlockSpacing: CGFloat = 4
    public static let columnGap: CGFloat = 24
}

// MARK: - §20 — Mouvement (avec repli Reduce Motion)

public enum SlateMotion {
    public static let fast: Double = 0.12, base: Double = 0.20, slow: Double = 0.30

    /// Respecte « Réduire les animations » : fondu seul, aucun déplacement.
    public static func standard(_ duration: Double = base, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: fast) : .easeInOut(duration: duration)
    }
    public static func emphasis(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: fast) : .spring(response: 0.35, dampingFraction: 0.8)
    }
}

// MARK: - Matériaux (avec repli Reduce Transparency)

/// Fond de sidebar : matériau `.sidebar`, remplacé par un aplat si la transparence est réduite.
public struct SlateSidebarBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    public init() {}
    public var body: some View {
        Group {
            if reduceTransparency { SlateColors.bgSidebarBase }
            else { Rectangle().fill(.background.secondary).background(.ultraThinMaterial) }
        }
        .ignoresSafeArea()
    }
}

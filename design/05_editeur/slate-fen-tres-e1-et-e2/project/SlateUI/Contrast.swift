//  Contrast.swift — SlateUI
//  Contraste WCAG mesuré (pas estimé). Sert à dériver l'aplat de sélection
//  au lieu de supposer que `accent.default` porte du texte 13–14 pt en AA.
//
//  Mesures sur les tokens bruts :
//    blanc sur accent.blue clair  #007AFF → 3.99:1  ✗ AA (texte < 18 pt)
//    blanc sur accent.blue sombre #0A84FF → 3.65:1  ✗ AA
//  D'où `SlateAccent.selectionFill` : l'accent assombri par pas de 2 %
//  jusqu'à atteindre 4.5:1 avec `text.onAccent`. Le token reste la source ;
//  seule sa luminosité est corrigée, la teinte est conservée.

import AppKit
import SwiftUI

public enum SlateContrast {

    /// Luminance relative WCAG 2.1 d'une couleur sRGB opaque.
    public static func luminance(_ color: NSColor) -> CGFloat {
        guard let c = color.usingColorSpace(.sRGB) else { return 0 }
        func lin(_ v: CGFloat) -> CGFloat {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.redComponent) + 0.7152 * lin(c.greenComponent) + 0.0722 * lin(c.blueComponent)
    }

    /// Ratio de contraste entre deux couleurs opaques.
    public static func ratio(_ a: NSColor, _ b: NSColor) -> CGFloat {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Aplatit `color` (éventuellement translucide) sur `background` avant mesure.
    public static func flatten(_ color: NSColor, over background: NSColor) -> NSColor {
        guard let c = color.usingColorSpace(.sRGB), let b = background.usingColorSpace(.sRGB) else { return color }
        let a = c.alphaComponent
        return NSColor(srgbRed: c.redComponent * a + b.redComponent * (1 - a),
                       green: c.greenComponent * a + b.greenComponent * (1 - a),
                       blue: c.blueComponent * a + b.blueComponent * (1 - a),
                       alpha: 1)
    }

    /// Assombrit `fill` jusqu'à ce que `text` (aplati dessus) atteigne `target`.
    public static func darkened(_ fill: NSColor, toMeet target: CGFloat, with text: NSColor) -> NSColor {
        guard var candidate = fill.usingColorSpace(.sRGB) else { return fill }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        candidate.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        var step = 0
        while step < 50 {
            let flat = flatten(text, over: candidate)
            if ratio(flat, candidate) >= target { return candidate }
            b = max(b - 0.02, 0)
            candidate = NSColor(hue: h, saturation: s, brightness: b, alpha: a)
            step += 1
        }
        return candidate
    }
}

public extension SlateAccent {
    /// Aplat de sélection portant du texte 13–14 pt : ≥ 4.5:1 avec `text.onAccent`, mesuré.
    /// Bleu → ≈ #0A6BE6 (4.94:1) dans les deux thèmes.
    var selectionFill: Color {
        Color(nsColor: .slateDynamic(
            light: SlateContrast.darkened(NSColor(hex: lightHex), toMeet: 4.5, with: onAccentNS),
            dark:  SlateContrast.darkened(NSColor(hex: darkHex),  toMeet: 4.5, with: onAccentNS),
            lightHC: SlateContrast.darkened(NSColor(hex: lightHex), toMeet: 7.0, with: onAccentNS),
            darkHC:  SlateContrast.darkened(NSColor(hex: darkHex),  toMeet: 7.0, with: onAccentNS)))
    }
    var selectionFillPressed: Color {
        Color(nsColor: .slateDynamic(
            light: SlateContrast.darkened(NSColor(hex: lightHex), toMeet: 6.0, with: onAccentNS),
            dark:  SlateContrast.darkened(NSColor(hex: darkHex),  toMeet: 6.0, with: onAccentNS)))
    }
    /// Texte secondaire posé sur `selectionFill` : blanc à 95 % (0,85 tombe à 4,28:1 — insuffisant).
    var onAccentSecondary: Color { self == .yellow ? .black.opacity(0.72) : .white.opacity(0.95) }

    var onAccentNS: NSColor { self == .yellow ? .black(0.88) : .white }
}

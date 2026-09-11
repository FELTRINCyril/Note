import SwiftUI

// Rendu SwiftUI (`Color`) des accents, pour les consommateurs qui n'ont pas besoin des
// composantes RGB brutes (ex: `AccentSwatchButton` dans `SlateFeatures`).
//
// Extrait de `SlateAccentColor.swift` : ce fichier depend de `slateAdaptiveColor` (interne
// a `SlateUI`, defini dans `SlateColor.swift`), le type pur reste lisible sans ce detail.

public extension SlateAccentColor {
    /// Aplat plein de cet accent, ADAPTATIF clair/sombre (equivalent `SlateColor.
    /// accentDefault`, mais pour un accent choisi explicitement plutot que l'accent
    /// COURANT de `ThemeManager`) -- utile pour un selecteur d'accent qui doit afficher
    /// les 8 pastilles simultanement, quel que soit l'accent actif.
    var color: Color {
        slateAdaptiveColor(light: lightRGB, dark: darkRGB)
    }

    /// `text.onAccent` pour CET accent (equivalent `SlateColor.textOnAccent`, meme
    /// nuance : accent EXPLICITE plutot que courant). Pendant de `color` pour peindre la
    /// coche/le glyphe pose sur la pastille (design P4 artboard A).
    var onAccentColor: Color {
        slateAdaptiveColor(light: onAccentRGB(dark: false), dark: onAccentRGB(dark: true))
    }
}

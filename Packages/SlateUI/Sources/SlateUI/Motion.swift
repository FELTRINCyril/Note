import SwiftUI

/// Tokens de mouvement, alignes sur `design/tokens.md` §20.
///
/// Toute animation de `SlateUI` doit passer par `SlateMotion.animation(duration:reduceMotion:)`
/// plutot que construire une `Animation` a la main, pour respecter systematiquement
/// "Reduce Motion" (design/tokens.md : "Fondu simple (opacite), aucun deplacement" ;
/// spec E2 Accessibilite : "pliage et collapse en fondu simple").
///
/// Ce fichier ne fabrique pas lui-meme le fondu : `reduceMotion == true` retourne `nil`
/// (pas d'animation implicite de position/rotation), et c'est a l'appelant de basculer
/// sur une transition `.opacity` explicite s'il veut un fondu anime malgre tout.
public enum SlateMotion {
    /// Survols, petits changements. Equivalent `motion.duration.fast`.
    public static let durationFast: Double = 0.12

    /// Transitions standard. Equivalent `motion.duration.base`.
    public static let durationBase: Double = 0.2

    /// Apparitions de panneaux, collapse de colonne. Equivalent `motion.duration.slow`.
    public static let durationSlow: Double = 0.3

    /// Courbe par defaut. Equivalent `motion.easing.standard`.
    public static let easingStandard: Animation = .easeInOut

    /// Courbe d'entree/sortie marquee. Equivalent `motion.easing.emphasis`.
    public static let easingEmphasis: Animation = .spring(response: 0.35, dampingFraction: 0.8)

    /// Construit l'animation a utiliser pour une duree donnee, ou `nil` si "Reduce
    /// Motion" est actif (l'appelant doit alors soit ne rien animer, soit ne transitionner
    /// que l'opacite via `.transition(.opacity)`).
    public static func animation(duration: Double, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: duration)
    }
}

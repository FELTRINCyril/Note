import SwiftUI

/// Une couleur RGB(A) exprimee en composantes `0...1`, utilisee pour les calculs
/// d'accessibilite WCAG.
///
/// Type dedie plutot que `Color` directement : les calculs de contraste ont besoin des
/// composantes brutes, et `Color` ne les expose pas de facon fiable independamment de
/// l'espace colorimetrique ou du theme actif. `SlateRGB` reste une valeur pure et
/// testable, sans dependre de l'environnement SwiftUI.
public struct SlateRGB: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Cree une couleur a partir d'un hex `"#RRGGBB"` (le `#` est optionnel).
    /// Retourne `nil` si la chaine n'est pas un hex RGB valide.
    public init?(hex: String, alpha: Double = 1) {
        var value = hex
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let intValue = UInt32(value, radix: 16) else {
            return nil
        }
        red = Double((intValue >> 16) & 0xFF) / 255
        green = Double((intValue >> 8) & 0xFF) / 255
        blue = Double(intValue & 0xFF) / 255
        self.alpha = alpha
    }

    public static let white = SlateRGB(red: 1, green: 1, blue: 1)
    public static let black = SlateRGB(red: 0, green: 0, blue: 0)

    /// Meme teinte, nouvelle opacite -- pratique pour deriver une variante `.subtle`/
    /// `focusRing`/selection de texte d'un aplat opaque sans repeter ses 3 composantes.
    public func withAlpha(_ alpha: Double) -> SlateRGB {
        SlateRGB(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Representation SwiftUI, pour construire les tokens de couleur exposes par `SlateColor`.
    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

/// Calculs de contraste WCAG 2.1.
///
/// ## Pourquoi ce type existe
/// `design/03_sidebar/Slate_E1-E2_coquille-sidebar.html` (section Accessibilite) affirme :
/// "libelle sur selection : blanc sur #007AFF = 4,55:1 (clair) et sur #0A84FF = 4,52:1
/// (sombre) OK AA". **Ces deux valeurs sont fausses.** Un calcul WCAG 2.1 correct donne :
/// - blanc sur `#007AFF` = **4,02:1**
/// - blanc sur `#0A84FF` = **3,65:1**
///
/// Le libelle de ligne est en 13 pt Regular (texte normal), donc le seuil AA applicable
/// est **4,5:1**, pas 3:1. Les deux valeurs reelles echouent AA.
///
/// Comme l'accent deviendra personnalisable par l'utilisateur (Phase 13,
/// `design/tokens.md` §7), on ne peut pas se contenter de corriger la constante : il faut
/// une regle generale, appliquee a chaque accent choisi, qui garantisse le contraste
/// AA du libelle sur selection. C'est le role de `darkening(_:toReachContrast:with:)`,
/// utilise par `SlateColor.accentSelectionFill`.
public enum WCAGContrast {
    /// Luminance relative WCAG 2.1 d'une couleur.
    ///
    /// Formule : composante `c` normalisee sur 255, lineaire = `c/12.92` si
    /// `c <= 0.03928` sinon `((c+0.055)/1.055)^2.4` ; `L = 0.2126*R + 0.7152*G + 0.0722*B`.
    public static func relativeLuminance(_ color: SlateRGB) -> Double {
        func linearize(_ component: Double) -> Double {
            component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        let red = linearize(color.red)
        let green = linearize(color.green)
        let blue = linearize(color.blue)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// Ratio de contraste WCAG 2.1 entre deux couleurs : `(Lclair + 0.05) / (Lsombre + 0.05)`.
    /// L'ordre des arguments n'importe pas : la couleur la plus claire des deux est
    /// toujours placee au numerateur.
    public static func ratio(_ first: SlateRGB, _ second: SlateRGB) -> Double {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Compose `foreground` (qui peut etre translucide, ex: `text.tertiary` a 26%
    /// d'opacite) au-dessus de `background` (opaque) et retourne le RGB opaque
    /// resultant, par alpha blending standard : `resultat = fg*alpha + bg*(1-alpha)`
    /// pour chaque composante.
    ///
    /// Necessaire pour mesurer le contraste REEL d'un texte translucide sur un fond
    /// donne : `ratio(foreground, background)` calcule a tort le contraste de
    /// `foreground` comme si elle etait opaque, en ignorant que le fond "transparait" a
    /// travers elle. C'est exactement l'erreur qui masquait le defaut du compteur de
    /// sidebar (`text.tertiary` a 26% sur `accentSelectionFill`) : composee, sa couleur
    /// reelle est un bleu clair proche du fond, pas le "gris fonce" que son alpha seul
    /// suggere.
    public static func compositeOverBackground(_ foreground: SlateRGB, _ background: SlateRGB) -> SlateRGB {
        let alpha = foreground.alpha
        func blend(_ fg: Double, _ bg: Double) -> Double {
            fg * alpha + bg * (1 - alpha)
        }
        return SlateRGB(
            red: blend(foreground.red, background.red),
            green: blend(foreground.green, background.green),
            blue: blend(foreground.blue, background.blue),
            alpha: 1
        )
    }

    /// Choisit la couleur de libelle (blanc ou noir) qui maximise le contraste avec
    /// `background`. Couvre le cas d'un accent clair (ex: jaune `#FFCC00`, spec :
    /// "Accent jaune -> texte noir 88%") avant tout assombrissement du fond.
    public static func labelColor(on background: SlateRGB) -> SlateRGB {
        ratio(.white, background) >= ratio(.black, background) ? .white : .black
    }

    /// Assombrit progressivement `background` (en reduisant sa luminosite HSB, teinte et
    /// saturation inchangees) jusqu'a ce que son contraste avec `label` atteigne au moins
    /// `target`. N'eclaircit jamais : si `background` satisfait deja `target`, il est
    /// retourne inchange. Si `target` est inatteignable (label trop proche du noir/blanc
    /// pur), retourne l'approximation la plus sombre atteinte.
    ///
    /// Multiplier les trois composantes RGB par le meme facteur de luminosite preserve
    /// exactement la teinte et la saturation HSB (les ratios R/G/B restent identiques,
    /// donc `V = max(R,G,B)` diminue seul) : c'est un assombrissement HSB valide sans
    /// passer par une conversion RGB<->HSB explicite.
    ///
    /// ## Le piege corrige (phase 4)
    /// `label` peut etre TRANSLUCIDE (ex: le premier plan secondaire de la spec E3, blanc
    /// a 95% d'opacite). Mesurer `ratio(label, candidate)` directement, sans composer
    /// l'alpha au-dessus de `candidate`, revient a mesurer le contraste de `label` comme
    /// s'il etait OPAQUE : la boucle s'arrete trop tot, des qu'un `candidate` opaque
    /// suffirait pour un `label` opaque, alors que le `label` REEL (translucide) y est en
    /// realite moins contraste (compose, il se rapproche visuellement de `candidate`).
    /// C'est exactement le defaut trouve en revue de phase 4 : la regle ciblait
    /// implicitement "blanc opaque >= 4,5:1" (le premier plan LE PLUS FACILE a satisfaire)
    /// au lieu de "blanc 95% >= 4,5:1" (le premier plan LE PLUS EXIGEANT qui se pose
    /// reellement sur l'aplat, l'extrait de la cellule de note) -- l'aplat obtenu
    /// (`#0071ED`) laissait alors le blanc 95% a ~4,26:1, un echec AA silencieux. Composer
    /// `label` sur `candidate` AVANT de mesurer resout le probleme pour toute opacite,
    /// y compris 100% (composer un premier plan opaque le laisse inchange : aucune
    /// regression sur les appels existants avec `label: .white`).
    public static func darkening(
        _ background: SlateRGB,
        toReachContrast target: Double,
        with label: SlateRGB,
        step: Double = 0.01
    ) -> SlateRGB {
        var brightness = 1.0
        var candidate = background
        while ratio(compositeOverBackground(label, candidate), candidate) < target, brightness > step {
            brightness -= step
            candidate = SlateRGB(
                red: background.red * brightness,
                green: background.green * brightness,
                blue: background.blue * brightness,
                alpha: background.alpha
            )
        }
        return candidate
    }

    /// Eclaircit progressivement `foreground` (melange vers le blanc) jusqu'a ce que son
    /// contraste avec `background` (opaque, fixe) atteigne au moins `target`. N'assombrit
    /// jamais : si `foreground` satisfait deja `target`, il est retourne inchange.
    ///
    /// Pendant de `darkening(_:toReachContrast:with:)`, pour le cas ou c'est le PREMIER
    /// PLAN qu'il faut ajuster contre un fond fixe -- typiquement un accent pose EN TEXTE
    /// sur `bg.editor` en theme sombre (`text.link`, design/tokens.md, "Couleur de texte
    /// derivee de l'accent") : assombrir davantage un accent deja sombre ne le detache pas
    /// d'un fond lui-meme tres sombre, il faut au contraire l'eclaircir.
    public static func lightening(
        _ foreground: SlateRGB,
        toReachContrast target: Double,
        with background: SlateRGB,
        step: Double = 0.01
    ) -> SlateRGB {
        var mix = 0.0
        var candidate = foreground
        while ratio(candidate, background) < target, mix < 1.0 {
            mix += step
            candidate = SlateRGB(
                red: foreground.red + (1 - foreground.red) * mix,
                green: foreground.green + (1 - foreground.green) * mix,
                blue: foreground.blue + (1 - foreground.blue) * mix,
                alpha: foreground.alpha
            )
        }
        return candidate
    }
}

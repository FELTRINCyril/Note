import Observation
import SwiftUI

/// Etat observable de l'apparence et de la typographie choisies par l'utilisateur
/// (design/tokens.md, artboard A de `design/_design_complet/Slate P4 - Reglages &
/// apparence.dc.html`). Source de verite unique pour :
/// - l'apparence (Systeme / Clair / Sombre), qui pilote `.preferredColorScheme` ;
/// - l'accent courant (`SlateAccentColor`), consomme par `SlateColor`/`SlateSemanticColors`
///   via `slateCurrentAccent()` ;
/// - la police du corps (SF Pro systeme ou New York serif) et un multiplicateur de taille
///   de texte cumulatif avec la taille systeme (Dynamic Type), consommes par `SlateFont`.
///
/// ## Partage global, comme `SlateAccessibility`
/// `SlateColor`/`SlateSemanticColors`/`SlateFont` restent des `enum` non isoles, lus depuis
/// des contextes tres varies (corps de vue, previews, tests) -- ils ne peuvent pas recevoir
/// `ThemeManager` en parametre a chaque appel sans casser toute leur API existante. Comme
/// pour "Increase Contrast" (`SlateAccessibility.shared`), la reference partagee
/// `ThemeManager.shared` fait le pont : les vues injectent la MEME instance dans
/// l'environnement (`.environment(ThemeManager.shared)`) pour l'ecran de reglages et toute
/// vue qui a besoin de la lire/l'ecrire, pendant que les tokens purs la lisent directement.
///
/// ## Persistance
/// `UserDefaults.standard`, pas `@AppStorage` : `ThemeManager` est une classe simple
/// (`@Observable`), pas une `View` -- combiner `@AppStorage` et la macro `@Observable` sur
/// la meme propriete stockee n'est pas supporte (les deux sont des macros/property wrappers
/// qui se disputent le stockage). Le resultat observable est le meme : lecture au demarrage,
/// ecriture a chaque changement.
///
/// ## v2 : reglage par workspace
/// Ces preferences sont globales a l'app pour l'instant (design/tokens.md ne distingue pas
/// de reglage par workspace). Le jour ou elles deviendront par-workspace, `ThemeManager`
/// devra cesser d'etre un singleton unique pour devenir une propriete du workspace actif --
/// non construit ici, volontairement, pour ne pas anticiper une phase non specifiee.
@MainActor
@Observable
public final class ThemeManager {
    /// Instance partagee. Voir la note "Partage global" ci-dessus.
    public static let shared = ThemeManager()

    /// Apparence choisie (design P4, artboard A : "Systeme / Clair / Sombre").
    public enum Appearance: String, CaseIterable, Sendable, Identifiable {
        case system
        case light
        case dark

        public var id: String { rawValue }

        /// Nom affiche (design P4).
        public var displayName: String {
            switch self {
            case .system: "Systeme"
            case .light: "Clair"
            case .dark: "Sombre"
            }
        }
    }

    /// Police du corps (design P4 : "SF Pro (systeme) ou New York (serif)").
    public enum BodyFontChoice: String, CaseIterable, Sendable, Identifiable {
        case sans
        case serif

        public var id: String { rawValue }

        /// Nom affiche (design P4).
        public var displayName: String {
            switch self {
            case .sans: "SF Pro (systeme)"
            case .serif: "New York (serif)"
            }
        }

        /// `Font.Design` correspondant, pour `SlateFont`.
        public var fontDesign: Font.Design {
            switch self {
            case .sans: .default
            case .serif: .serif
            }
        }
    }

    /// Bornes du curseur "Taille du texte" (design P4). Multiplicateur applique en plus de
    /// la taille systeme (Dynamic Type) -- 1.0 = taille par defaut de Slate, inchangee.
    public static let textSizeMultiplierRange: ClosedRange<Double> = 0.85...1.3

    public var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: DefaultsKey.appearance) }
    }

    public var accent: SlateAccentColor {
        didSet {
            UserDefaults.standard.set(accent.rawValue, forKey: DefaultsKey.accent)
            SlateThemeState.shared.accent = accent
        }
    }

    public var bodyFont: BodyFontChoice {
        didSet {
            UserDefaults.standard.set(bodyFont.rawValue, forKey: DefaultsKey.bodyFont)
            SlateThemeState.shared.bodyFontDesign = bodyFont.fontDesign
        }
    }

    public var textSizeMultiplier: Double {
        didSet {
            let clamped = textSizeMultiplier.clamped(to: Self.textSizeMultiplierRange)
            if clamped != textSizeMultiplier {
                textSizeMultiplier = clamped
                return
            }
            UserDefaults.standard.set(textSizeMultiplier, forKey: DefaultsKey.textSizeMultiplier)
            SlateThemeState.shared.textSizeMultiplier = textSizeMultiplier
        }
    }

    /// "Afficher la couverture des notes" (design P4, artboard A). Lu directement par
    /// `NoteHeaderView` (`SlateEditor`, autorisation exceptionnelle de la Phase 13 --
    /// UNIQUEMENT cette lecture de reglage) via `@Environment(ThemeManager.self)` : ce
    /// reglage n'a pas besoin du miroir thread-safe `SlateThemeState` (pas consomme par
    /// un token `SlateColor`/`SlateFont` calcule hors du thread principal).
    public var showsNoteCover: Bool {
        didSet { UserDefaults.standard.set(showsNoteCover, forKey: DefaultsKey.showsNoteCover) }
    }

    /// "Reduire la transparence de la barre laterale" (design P4). S'AJOUTE au reglage
    /// systeme "Reduire la transparence" (`accessibilityReduceTransparency`), ne
    /// l'ecrase jamais : voir `SidebarMaterialBackground.swift`, qui lit les deux et
    /// opacifie des que l'un OU l'autre est actif -- coherent avec la note du design P4
    /// ("Ces deux options suivent par defaut les reglages d'accessibilite de macOS ; les
    /// cocher ici force le comportement dans Slate seulement").
    public var reducesSidebarTransparency: Bool {
        didSet {
            UserDefaults.standard.set(reducesSidebarTransparency, forKey: DefaultsKey.reducesSidebarTransparency)
            SlateThemeState.shared.reducesSidebarTransparencyOverride = reducesSidebarTransparency
        }
    }

    /// "Augmenter le contraste des separateurs" (design P4). S'AJOUTE au reglage systeme
    /// "Augmenter le contraste" (`SlateAccessibility`), meme logique OR que
    /// `reducesSidebarTransparency` -- voir `SlateColor.separator`/`.borderDefault`/
    /// `.borderStrong`.
    public var increasesSeparatorContrast: Bool {
        didSet {
            UserDefaults.standard.set(increasesSeparatorContrast, forKey: DefaultsKey.increasesSeparatorContrast)
            SlateThemeState.shared.increasesSeparatorContrastOverride = increasesSeparatorContrast
        }
    }

    /// `ColorScheme` a passer a `.preferredColorScheme(_:)` : `nil` pour "Systeme" (laisse
    /// macOS decider), sinon la valeur forcee.
    public var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private enum DefaultsKey {
        static let appearance = "slate.theme.appearance"
        static let accent = "slate.theme.accent"
        static let bodyFont = "slate.theme.bodyFont"
        static let showsNoteCover = "slate.theme.showsNoteCover"
        static let reducesSidebarTransparency = "slate.theme.reducesSidebarTransparency"
        static let increasesSeparatorContrast = "slate.theme.increasesSeparatorContrast"
        static let textSizeMultiplier = "slate.theme.textSizeMultiplier"
    }

    private init() {
        let defaults = UserDefaults.standard
        appearance = Appearance(rawValue: defaults.string(forKey: DefaultsKey.appearance) ?? "") ?? .system
        let initialAccent = SlateAccentColor(rawValue: defaults.string(forKey: DefaultsKey.accent) ?? "") ?? .blue
        let initialBodyFont = BodyFontChoice(rawValue: defaults.string(forKey: DefaultsKey.bodyFont) ?? "") ?? .sans
        let storedMultiplier = defaults.object(forKey: DefaultsKey.textSizeMultiplier) as? Double
        let initialTextSizeMultiplier = (storedMultiplier ?? 1.0).clamped(to: Self.textSizeMultiplierRange)
        // "Afficher la couverture" est active par defaut (comportement historique, avant
        // que ce reglage n'existe) ; les deux options d'accessibilite sont desactivees
        // par defaut, le reglage systeme suffisant deja pour qui en a besoin.
        let initialShowsNoteCover = defaults.object(forKey: DefaultsKey.showsNoteCover) as? Bool ?? true
        let initialReducesSidebarTransparency = defaults.bool(forKey: DefaultsKey.reducesSidebarTransparency)
        let initialIncreasesSeparatorContrast = defaults.bool(forKey: DefaultsKey.increasesSeparatorContrast)

        accent = initialAccent
        bodyFont = initialBodyFont
        textSizeMultiplier = initialTextSizeMultiplier
        showsNoteCover = initialShowsNoteCover
        reducesSidebarTransparency = initialReducesSidebarTransparency
        increasesSeparatorContrast = initialIncreasesSeparatorContrast

        // `didSet` ne se declenche pas pendant l'assignation initiale d'un stored
        // property dans `init` : sans cette synchronisation explicite, `SlateThemeState`
        // resterait sur ses valeurs par defaut tant que l'utilisateur n'a rien change.
        SlateThemeState.shared.accent = initialAccent
        SlateThemeState.shared.bodyFontDesign = initialBodyFont.fontDesign
        SlateThemeState.shared.textSizeMultiplier = initialTextSizeMultiplier
        SlateThemeState.shared.reducesSidebarTransparencyOverride = initialReducesSidebarTransparency
        SlateThemeState.shared.increasesSeparatorContrastOverride = initialIncreasesSeparatorContrast
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Miroir THREAD-SAFE (verrou, pas d'isolation d'acteur) de l'etat de `ThemeManager`
/// utile aux tokens purs (`SlateColor`, `SlateSemanticColors`, `SlateFont`).
///
/// ## Pourquoi pas `MainActor.assumeIsolated`, comme `slateCurrentlyIncreasesContrast()`
/// Un premier essai calque sur ce pattern existant (voir `SlateAccessibility.swift`)
/// faisait planter des tests EXISTANTS et INCHANGES par cette phase
/// (`EditorAccessibilityTests`, `struct` non `@MainActor`) : Swift Testing execute les
/// `@Test` non isoles sur un pool de threads d'arriere-plan, pas necessairement le thread
/// principal, et `MainActor.assumeIsolated` DECLENCHE UN TRAP IMMEDIAT des qu'il est
/// appele depuis un thread qui n'execute pas reellement le MainActor -- confirme par la
/// trace de crash (`slateCurrentAccent()` -> `SlateAccent.defaultDarkRGB` ->
/// `EditorAccessibilityTests.opaqueReinforcementMeetsNonTextMinimumInDark()`, thread 5,
/// SIGTRAP). `slateCurrentlyIncreasesContrast()` porte la MEME fragilite latente ; elle ne
/// s'est simplement pas encore manifestee dans la suite actuelle. Signale dans le rapport
/// de livraison plutot que corrige ici : hors perimetre des deux corrections demandees.
///
/// Un verrou simple (`NSLock`) sur des types valeur `Sendable` est suffisant et sans
/// risque de cette classe de plantage, quel que soit le thread appelant.
private final class SlateThemeState: @unchecked Sendable {
    static let shared = SlateThemeState()

    private let lock = NSLock()
    private var storedAccent: SlateAccentColor = .blue
    private var storedBodyFontDesign: Font.Design = .default
    private var storedTextSizeMultiplier: Double = 1.0
    private var storedIncreasesContrast = false
    private var storedReducesSidebarTransparencyOverride = false
    private var storedIncreasesSeparatorContrastOverride = false

    var accent: SlateAccentColor {
        get { lock.withLock { storedAccent } }
        set { lock.withLock { storedAccent = newValue } }
    }

    var bodyFontDesign: Font.Design {
        get { lock.withLock { storedBodyFontDesign } }
        set { lock.withLock { storedBodyFontDesign = newValue } }
    }

    var textSizeMultiplier: Double {
        get { lock.withLock { storedTextSizeMultiplier } }
        set { lock.withLock { storedTextSizeMultiplier = newValue } }
    }

    var increasesContrast: Bool {
        get { lock.withLock { storedIncreasesContrast } }
        set { lock.withLock { storedIncreasesContrast = newValue } }
    }

    /// Reglage Slate "Reduire la transparence de la barre laterale" (design P4) --
    /// DISTINCT du reglage systeme, qui a son propre canal (`accessibilityReduceTransparency`,
    /// lu directement par `SidebarMaterialBackground.swift`, une `View`). Les deux se
    /// combinent en OU, jamais l'un n'ecrase l'autre.
    var reducesSidebarTransparencyOverride: Bool {
        get { lock.withLock { storedReducesSidebarTransparencyOverride } }
        set { lock.withLock { storedReducesSidebarTransparencyOverride = newValue } }
    }

    /// Reglage Slate "Augmenter le contraste des separateurs" (design P4) -- DISTINCT du
    /// reglage systeme general (`increasesContrast` ci-dessus). Meme logique OR que
    /// `reducesSidebarTransparencyOverride`.
    var increasesSeparatorContrastOverride: Bool {
        get { lock.withLock { storedIncreasesSeparatorContrastOverride } }
        set { lock.withLock { storedIncreasesSeparatorContrastOverride = newValue } }
    }
}

/// Lit l'accent courant, depuis N'IMPORTE QUEL thread (voir `SlateThemeState`).
func slateCurrentAccent() -> SlateAccentColor {
    SlateThemeState.shared.accent
}

/// Lit la police du corps courante, depuis n'importe quel thread. Voir `slateCurrentAccent()`.
func slateCurrentBodyFontDesign() -> Font.Design {
    SlateThemeState.shared.bodyFontDesign
}

/// Lit le multiplicateur de taille de texte courant, depuis n'importe quel thread. Voir
/// `slateCurrentAccent()`.
func slateCurrentTextSizeMultiplier() -> Double {
    SlateThemeState.shared.textSizeMultiplier
}

/// Lit la preference "Augmenter le contraste", depuis N'IMPORTE QUEL thread.
///
/// Meme raison d'etre que `slateCurrentAccent()` : cette valeur est lue pendant le
/// calcul des tokens de couleur, qui peut se produire hors du thread principal. Swift
/// Testing execute notamment les `@Test` non isoles sur des threads d'arriere-plan, et
/// un `MainActor.assumeIsolated` y provoque un SIGTRAP -- ce n'est pas une hypothese,
/// c'est le plantage rencontre en phase 13 sur `EditorAccessibilityTests`, des tests
/// pourtant preexistants et inchanges.
func slateCurrentIncreasesContrast() -> Bool {
    SlateThemeState.shared.increasesContrast
}

/// Publie la preference systeme dans le miroir thread-safe. Appele par
/// `SlateAccessibility`, seul proprietaire de la valeur.
@MainActor
func slatePublishIncreasesContrast(_ value: Bool) {
    SlateThemeState.shared.increasesContrast = value
}

/// Lit le reglage Slate "Reduire la transparence de la barre laterale", depuis
/// n'importe quel thread. Voir `SlateThemeState.reducesSidebarTransparencyOverride` --
/// DISTINCT du reglage systeme (`accessibilityReduceTransparency`, lu par
/// `SidebarMaterialBackground.swift` directement, car c'est une valeur d'environnement
/// SwiftUI, pas un token). Les deux se combinent en OU au point d'usage.
func slateReducesSidebarTransparencyOverride() -> Bool {
    SlateThemeState.shared.reducesSidebarTransparencyOverride
}

/// Combine le reglage systeme "Augmenter le contraste" ET le reglage Slate
/// "Augmenter le contraste des separateurs" (OU logique -- l'un ou l'autre suffit).
/// Point d'entree UNIQUE pour `SlateColor.separator`/`.borderDefault`/`.borderStrong` :
/// aucun de ces tokens ne doit lire `slateCurrentIncreasesContrast()` ou
/// `increasesSeparatorContrastOverride` separement.
func slateSeparatorsUseIncreasedContrast() -> Bool {
    slateCurrentIncreasesContrast() || SlateThemeState.shared.increasesSeparatorContrastOverride
}

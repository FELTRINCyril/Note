import AppKit
import Observation

/// Etat observable de la preference systeme "Increase Contrast" (Accessibilite >
/// Affichage), republie pour que SwiftUI puisse re-rendre au bon moment.
///
/// ## Pourquoi ce type existe
/// La spec E3 exige deux choses en mode Increase Contrast (`design/04_liste_notes/
/// Slate E1-E3.dc.html`, "Accessibilite") : l'aplat de selection recalcule pour 7:1 au
/// lieu de 4,5:1, et `text.secondary` renforce de 0,50 a 0,72 d'opacite. Un agent de la
/// phase 3 avait affirme cette preference indetectable parce que `NSAppearance.bestMatch`
/// ne distingue que clair/sombre -- exact, mais incomplet : elle se lit via
/// `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast`, et les changements
/// sont notifies par `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`.
///
/// ## Limite documentee de `NSColor(name:dynamicProvider:)`
/// `slateAdaptiveColor` (voir `SlateColor.swift`) construit des couleurs adaptatives via
/// `NSColor(name:dynamicProvider:)` : AppKit re-invoque ce bloc quand `NSAppearance`
/// resout differemment (bascule clair/sombre), mais **pas** quand seule "Increase
/// Contrast" change -- l'apparence resolue clair/sombre reste identique, donc AppKit n'a
/// aucune raison de rappeler le `dynamicProvider`. Une couleur construite ainsi resterait
/// figee sur la valeur lue au premier rendu, meme apres bascule de la preference.
///
/// La solution retenue ici : ne PAS essayer de lire "Increase Contrast" depuis
/// l'interieur d'un `dynamicProvider` (ca ne se declenche pas au bon moment), mais
/// observer la notification systeme et republier l'etat via un type `@Observable`. Les
/// tokens qui en dependent (`SlateColor.accentSelectionFill`, `SlateColor.textSecondary`)
/// deviennent des proprietes CALCULEES (pas des `let` statiques) qui lisent
/// `SlateAccessibility.shared.isIncreaseContrastEnabled` a chaque acces -- puisque
/// l'acces a une propriete `@Observable` a l'interieur du `body` d'une `View` SwiftUI
/// est automatiquement suivi par le framework d'observation, ceci suffit a re-rendre les
/// vues concernees sans avoir besoin d'un `@Environment` dedie.
///
/// Limite residuelle : un code qui capture la `Color` renvoyee dans une variable locale
/// AVANT le rendu (plutot que de la recalculer a chaque acces dans `body`) ne beneficiera
/// pas de la reactivite. C'est un piege general des tokens Slate bases sur des `Color`
/// calculees, pas specifique a cette preference.
@MainActor
@Observable
public final class SlateAccessibility {
    /// Instance partagee : la preference systeme est globale au processus, pas de raison
    /// d'en avoir plusieurs. Les vues la lisent directement (`SlateAccessibility.shared.
    /// isIncreaseContrastEnabled`) plutot que de la recevoir en parametre.
    public static let shared = SlateAccessibility()

    public private(set) var isIncreaseContrastEnabled: Bool

    // `@ObservationIgnored` : cette propriete est un detail d'implementation (le jeton
    // d'observation NotificationCenter), jamais lue depuis une vue -- pas de raison que
    // la macro `@Observable` la fasse suivre. Necessaire aussi pour que
    // `nonisolated(unsafe)` s'applique reellement : sans cet attribut, la macro
    // synthetise un accesseur qui rend l'annotation sans effet (avertissement du
    // compilateur). `nonisolated(unsafe)`, pas `nonisolated` seul, parce que
    // `NSObjectProtocol` ne conforme pas a `Sendable`. `var`, pas `let` : `self` est
    // capture (faiblement) par le bloc qui produit la valeur elle-meme
    // (`NotificationCenter.addObserver`), donc une affectation directe en `let` echoue a
    // l'analyse d'initialisation definie de Swift ("used before being initialized"). Le
    // jeton n'est ecrit qu'une fois, dans `init` ; le `deinit` (toujours nonisole, meme
    // sur une classe `@MainActor`) est sa seule autre lecture -- pas de risque de course
    // reelle malgre l'annotation qui desactive la verification du compilateur.
    @ObservationIgnored
    nonisolated(unsafe) private var observer: (any NSObjectProtocol)?

    private init() {
        isIncreaseContrastEnabled = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        observer = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func refresh() {
        isIncreaseContrastEnabled = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
}

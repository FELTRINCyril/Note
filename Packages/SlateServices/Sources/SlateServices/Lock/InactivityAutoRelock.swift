import Foundation

/// Regle de re-verrouillage automatique par inactivite (`docs/12_verrouillage.md`,
/// reglages : "Apres 5 minutes d'inactivite").
///
/// Type pur, sans dependance a une horloge/timer reelle, pour rester testable sur ses
/// bornes exactes. Ne declenche rien lui-meme : c'est a l'appelant (future UI, hors
/// perimetre de cette tache - `SlateServices`/`SlateModel` uniquement) de faire tourner
/// un timer/observer de cycle de vie et d'appeler `shouldRelock(lastActivityAt:now:)`
/// puis, le cas echeant, `LockService.lock(_:)`.
///
/// Les deux autres declencheurs de re-verrouillage cites par `docs/12_verrouillage.md`
/// (fermeture de la note, verrouillage de l'app) ne relevent pas d'une duree a
/// comparer : ce sont des evenements instantanes, geres directement par un appel a
/// `LockService.lock(_:)` au moment ou ils surviennent, sans passer par ce type.
public struct InactivityAutoRelock: Sendable, Equatable {
    /// Duree d'inactivite au-dela de laquelle une note doit se re-verrouiller.
    public let threshold: TimeInterval

    /// 5 minutes, valeur par defaut de `docs/12_verrouillage.md` (reglages).
    public static let defaultThreshold: TimeInterval = 5 * 60

    public init(threshold: TimeInterval = defaultThreshold) {
        self.threshold = threshold
    }

    /// Vrai si le temps ecoule entre `lastActivityAt` et `now` atteint ou depasse
    /// `threshold`. Borne inclusive volontaire (`>=`, pas `>`) : a l'instant exact du
    /// seuil, la note doit deja etre consideree inactive, coherent avec l'intitule
    /// "apres 5 minutes" (au bout de 5 minutes, pas juste apres).
    public func shouldRelock(lastActivityAt: Date, now: Date = .now) -> Bool {
        now.timeIntervalSince(lastActivityAt) >= threshold
    }
}

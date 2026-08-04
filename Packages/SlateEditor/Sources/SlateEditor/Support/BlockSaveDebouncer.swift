import Foundation

/// Jeton d'annulation d'un travail programme par un `BlockSaveDebounceScheduling`
/// (voir ce protocole). Isole au `MainActor` comme le reste du mecanisme de debounce :
/// toute la chaine de sauvegarde d'un bloc (lecture/ecriture du modele, `ModelContext`)
/// vit deja sur l'acteur principal, ce type ne fait pas exception.
@MainActor
public protocol BlockSaveDebounceToken: AnyObject {
    /// Annule le travail s'il n'a pas encore ete execute. Sans effet si le travail a
    /// deja tourne (ou a deja ete annule).
    func cancel()
}

/// Abstraction du "temps qui passe" pour `BlockSaveDebouncer` (docs/05_editeur_blocs.md,
/// sous-etape 5.2, point 6 : "une fonction/type isolable avec une horloge injectee
/// plutot qu'un Task.sleep en dur, pour que le test soit deterministe et rapide").
///
/// L'implementation reelle (`WallClockDebounceScheduler`) retarde reellement
/// l'execution via un `Timer`. Les tests injectent un double qui capture le travail
/// programme SANS attendre de vraies millisecondes, et le declenchent manuellement au
/// moment choisi par le test -- voir `RecordingDebounceScheduler` dans
/// `BlockSaveDebouncerTests`.
@MainActor
public protocol BlockSaveDebounceScheduling {
    /// Programme `action` pour execution apres `interval` secondes. Retourne un jeton
    /// permettant d'annuler avant execution.
    func schedule(after interval: TimeInterval, action: @escaping @MainActor () -> Void) -> any BlockSaveDebounceToken
}

/// Implementation reelle de `BlockSaveDebounceScheduling` : un `Timer` sur la boucle
/// d'execution principale.
///
/// Le bloc de `Timer.scheduledTimer(withTimeInterval:repeats:block:)` n'est PAS
/// `@Sendable` (API Foundation anterieure a la concurrence structuree, contrairement a
/// `DispatchQueue.asyncAfter`) : capturer une reference non-Sendable isolee au
/// `MainActor` y est donc licite sans contournement (`@unchecked Sendable`,
/// `nonisolated(unsafe)`), exigence explicite de la tache. Le timer est cree et se
/// declenche sur le thread principal : `MainActor.assumeIsolated` documente cette
/// garantie plutot que de la contourner silencieusement.
@MainActor
public final class WallClockDebounceScheduler: BlockSaveDebounceScheduling {
    public init() {}

    public func schedule(
        after interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> any BlockSaveDebounceToken {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            MainActor.assumeIsolated {
                action()
            }
        }
        return TimerToken(timer: timer)
    }

    private final class TimerToken: BlockSaveDebounceToken {
        private let timer: Timer
        init(timer: Timer) { self.timer = timer }
        func cancel() { timer.invalidate() }
    }
}

/// Debounce d'une action de sauvegarde : chaque appel a `schedule` repousse l'echeance,
/// seule la DERNIERE action programmee finit par s'executer (docs/05_editeur_blocs.md,
/// sous-etape 5.2, point 3 : "ne pas ecrire a chaque frappe").
///
/// `flush()` est le contrepoids obligatoire de ce motif : sans lui, la derniere frappe
/// avant une perte de focus, un changement de note ou une fermeture de vue serait
/// perdue (le minuteur en cours serait simplement abandonne). `RichTextBlockView`
/// appelle `flush()` a ces trois moments precis -- voir sa documentation.
@MainActor
public final class BlockSaveDebouncer {
    private let scheduler: any BlockSaveDebounceScheduling
    private let interval: TimeInterval
    private var pendingToken: (any BlockSaveDebounceToken)?
    private var pendingAction: (@MainActor () -> Void)?

    /// - Parameter interval: delai d'inactivite avant sauvegarde reelle. 600 ms : assez
    ///   court pour qu'une pause naturelle de frappe declenche la sauvegarde, assez long
    ///   pour qu'une saisie continue n'ecrive jamais a chaque caractere.
    public init(
        interval: TimeInterval = 0.6,
        scheduler: any BlockSaveDebounceScheduling = WallClockDebounceScheduler()
    ) {
        self.interval = interval
        self.scheduler = scheduler
    }

    /// Programme `action` pour execution differee. Annule tout travail deja en attente
    /// avant de programmer le nouveau : c'est ce qui fait qu'une frappe rapide ne
    /// declenche qu'UNE seule sauvegarde a la fin, pas une par caractere.
    public func schedule(_ action: @escaping @MainActor () -> Void) {
        pendingToken?.cancel()
        pendingAction = action
        pendingToken = scheduler.schedule(after: interval) { [weak self] in
            self?.pendingToken = nil
            self?.pendingAction = nil
            action()
        }
    }

    /// Execute IMMEDIATEMENT le travail en attente (s'il y en a) et annule le minuteur
    /// en cours. Idempotent : sans effet si rien n'est en attente.
    ///
    /// - Returns: `true` si un travail en attente a effectivement ete execute.
    @discardableResult
    public func flush() -> Bool {
        guard let pendingAction else { return false }
        pendingToken?.cancel()
        pendingToken = nil
        self.pendingAction = nil
        pendingAction()
        return true
    }

    /// Abandonne le travail en attente SANS l'executer (contrairement a `flush()`).
    /// Reserve aux cas ou l'action programmee est devenue obsolete (ex: le bloc va etre
    /// entierement remplace par du contenu externe) -- non utilise en 5.2, mais expose
    /// pour ne pas avoir a faire evoluer cette API en 5.3.
    public func cancelWithoutFlushing() {
        pendingToken?.cancel()
        pendingToken = nil
        pendingAction = nil
    }
}

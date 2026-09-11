import SwiftUI
import SlateServices

/// Injection de `LockService` (`SlateServices`) dans l'environnement SwiftUI, meme
/// motif que `AppState`/`NoteActionsProviding` (voir `AppState.swift`).
///
/// Contrairement a `NoteActionsProviding`, `LockService` n'a pas besoin d'un
/// `ModelContext` a la construction (il ne parle qu'au Keychain/`LAContext` -- voir sa
/// documentation) : la valeur par defaut de l'environnement EST deja le service reel,
/// aucun point de branchement explicite n'est necessaire dans `MainWindowView`. Une
/// vue qui veut un service different (tests, previews) passe par
/// `.environment(\.lockService, ...)` comme n'importe quelle autre valeur
/// d'environnement.
private struct LockServiceKey: EnvironmentKey {
    static let defaultValue = LockService()
}

extension EnvironmentValues {
    /// Acces au service de verrouillage depuis n'importe quelle vue :
    /// `@Environment(\.lockService) private var lockService`.
    public var lockService: LockService {
        get { self[LockServiceKey.self] }
        set { self[LockServiceKey.self] = newValue }
    }
}

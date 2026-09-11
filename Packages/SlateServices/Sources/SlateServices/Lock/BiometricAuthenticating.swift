import Foundation
import LocalAuthentication

/// Abstraction sur `LocalAuthentication`, pour permettre a `LockService` d'etre testee
/// sans jamais declencher une vraie invite Touch ID/Face ID (impossible en test
/// automatise, et non souhaitable : cf. consigne de cette phase). Une seule
/// implementation de production (`SystemBiometricAuthenticator`, basee sur
/// `LAContext`) et une implementation factice reservee aux tests
/// (`SlateServicesTests`).
public protocol BiometricAuthenticating: Sendable {
    /// Vrai si Touch ID/Face ID est disponible et configure sur cette machine, a cet
    /// instant. Peut changer entre deux appels (ex. l'utilisateur desactive Touch ID
    /// dans Reglages Systeme pendant que l'app tourne) : ne jamais mettre en cache
    /// cette valeur au-dela d'un seul cycle d'affichage.
    func isBiometricsAvailable() -> Bool

    /// Declenche une authentification biometrique. Retourne normalement en cas de
    /// succes ; leve une erreur en cas d'echec, d'annulation par l'utilisateur, ou de
    /// repli explicite vers le mot de passe systeme (non utilise ici, `LockService`
    /// gere son propre mot de passe d'app).
    func authenticate(reason: String) async throws
}

/// Implementation de production, basee sur `LAContext`.
///
/// Une nouvelle instance de `LAContext` est creee a chaque appel plutot que reutilisee
/// : `LAContext` n'est pas concue pour etre partagee entre plusieurs authentifications
/// (son etat interne, notamment une authentification biometrique deja reussie
/// recemment, doit rester scope a une seule tentative de deverrouillage de note).
public struct SystemBiometricAuthenticator: BiometricAuthenticating {
    public init() {}

    public func isBiometricsAvailable() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    public func authenticate(reason: String) async throws {
        let context = LAContext()
        // `LAPolicy.deviceOwnerAuthenticationWithBiometrics` (et non
        // `.deviceOwnerAuthentication`) : jamais de repli automatique vers le mot de
        // passe **du compte macOS**. Le repli mot de passe de cette phase est celui,
        // distinct, defini par `LockService` (voir sa documentation) - melanger les
        // deux serait une confusion de perimetres de securite.
        _ = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
    }
}

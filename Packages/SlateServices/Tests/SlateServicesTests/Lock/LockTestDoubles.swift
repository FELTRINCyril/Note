import Foundation

@testable import SlateServices

/// Implementation en memoire de `SecretStore`, reservee aux tests : evite de polluer
/// le trousseau reel de la machine qui execute les tests, et rend les tests
/// deterministes et rejouables sans autorisation d'acces au Keychain.
final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func read(key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    @discardableResult
    func write(key: String, value: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
        return true
    }

    @discardableResult
    func delete(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
        return true
    }
}

/// `SecretStore` qui echoue systematiquement en ecriture, pour tester le
/// comportement de `LockService.setPassword` face a un Keychain indisponible.
final class FailingSecretStore: SecretStore, @unchecked Sendable {
    func read(key: String) -> Data? { nil }

    @discardableResult
    func write(key: String, value: Data) -> Bool { false }

    @discardableResult
    func delete(key: String) -> Bool { true }
}

/// Erreur factice levee par `FakeBiometricAuthenticator` pour simuler un echec
/// d'authentification (mauvaise empreinte, annulation par l'utilisateur...).
struct FakeBiometricError: Error {}

/// Double de test de `BiometricAuthenticating` : jamais de vraie invite Touch
/// ID/Face ID (impossible en test automatise), comportement entierement pilote par
/// les proprietes exposees ici.
final class FakeBiometricAuthenticator: BiometricAuthenticating, @unchecked Sendable {
    var available = true
    var succeeds = true

    func isBiometricsAvailable() -> Bool { available }

    func authenticate(reason: String) async throws {
        guard succeeds else { throw FakeBiometricError() }
    }
}

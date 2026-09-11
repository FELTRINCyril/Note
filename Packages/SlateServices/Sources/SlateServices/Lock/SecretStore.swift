import Foundation
import Security

/// Abstraction de stockage d'un secret opaque (`Data`), utilisee par `LockService`.
///
/// Deux raisons a cette indirection plutot qu'appeler directement le Keychain depuis
/// `LockService` :
/// - **Testabilite** : les tests de `LockService` (verification de mot de passe,
///   absence de recuperation en clair, cycle definir/verifier/supprimer) ne doivent
///   ni polluer le trousseau reel de la machine qui les execute, ni dependre d'une
///   autorisation d'acces Keychain interactive en environnement de test/CI. Une
///   implementation en memoire (voir `SlateServicesTests`) remplit exactement le
///   meme contrat.
/// - **Auditabilite** : toute la logique "quoi stocker, sous quelle cle, comment le
///   comparer" reste dans `LockService`/`PasswordHasher` ; ce protocole ne fait que
///   lire/ecrire des octets opaques, il n'a aucune connaissance du mot de passe ou du
///   sel qu'il transporte.
public protocol SecretStore: Sendable {
    func read(key: String) -> Data?

    @discardableResult
    func write(key: String, value: Data) -> Bool

    @discardableResult
    func delete(key: String) -> Bool
}

/// Implementation de production : Keychain macOS (classe "generic password").
///
/// Choix de securite explicites :
/// - `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` : le secret n'est lisible que
///   session ouverte, et n'est **jamais synchronise vers le trousseau iCloud**
///   (contrairement au comportement par defaut d'iCloud Keychain pour certaines
///   classes d'attributs). Le mot de passe de verrouillage de l'app est une donnee
///   locale a cette installation, elle ne doit pas se propager silencieusement vers
///   un autre Mac du meme compte iCloud.
/// - Jamais de journalisation de `value` : ce type ne fait que transporter des
///   octets deja opaques (sel, verificateur derive) vers/depuis `SecItem*`.
public struct KeychainSecretStore: SecretStore {
    /// "Service" logique Keychain regroupant toutes les entrees de verrouillage de
    /// l'app, distinct de toute autre entree Keychain de Slate.
    private static let service = "com.slate.applock"

    public init() {}

    public func read(key: String) -> Data? {
        var query = Self.baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    public func write(key: String, value: Data) -> Bool {
        // Toujours repartir d'un etat propre : `SecItemAdd` echoue
        // (`errSecDuplicateItem`) si une entree existe deja pour cette cle, et cette
        // methode represente un "set" (definir/redefinir), jamais un "add" strict.
        delete(key: key)

        var query = Self.baseQuery(for: key)
        query[kSecValueData as String] = value
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    @discardableResult
    public func delete(key: String) -> Bool {
        let status = SecItemDelete(Self.baseQuery(for: key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}

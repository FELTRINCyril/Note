import CryptoKit
import Foundation

/// Derivation du mot de passe de verrouillage (PBKDF2-HMAC-SHA256, RFC 8018),
/// utilisee par `LockService` pour ne **jamais** stocker ni pouvoir retrouver le mot
/// de passe en clair (voir la documentation de securite de `LockService`) : seul un
/// verificateur derive (sel + cle derivee) est conserve, la comparaison se fait en
/// re-derivant depuis le mot de passe propose.
///
/// Implementee a la main au-dessus de `CryptoKit.HMAC<SHA256>` plutot qu'avec
/// `CommonCrypto` (qui fournit `CCKeyDerivationPBKDF`) : `CommonCrypto` n'est pas
/// importable proprement depuis un module Swift Package sur cette configuration sans
/// cible C dediee et son module map, alors que `CryptoKit` est un module Swift natif
/// deja disponible. Correction verifiee par test contre des vecteurs de reference
/// `hashlib.pbkdf2_hmac` de Python (voir `PasswordHasherTests`).
enum PasswordHasher {
    /// Nombre d'iterations HMAC. 200 000 est dans la fourchette recommandee par
    /// l'OWASP (2023) pour PBKDF2-HMAC-SHA256 : couteux pour une attaque hors ligne
    /// par force brute sur le verificateur, tout en restant de l'ordre de quelques
    /// dizaines de millisecondes pour la verification interactive unique faite ici.
    static let iterationCount = 200_000

    /// Taille du sel genere pour chaque nouveau mot de passe.
    static let saltByteCount = 16

    /// Taille de la cle derivee stockee comme verificateur.
    static let derivedKeyByteCount = 32

    /// Taille de sortie de SHA256, necessaire au decoupage en blocs de PBKDF2.
    private static let hashByteCount = 32

    /// Sel aleatoire cryptographiquement sur, propre a chaque definition de mot de
    /// passe (jamais reutilise entre deux mots de passe, meme si l'utilisateur
    /// redefinit deux fois le meme mot de passe).
    static func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: saltByteCount)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: .min ... .max)
        }
        return Data(bytes)
    }

    /// Derive `password` avec `salt` selon PBKDF2-HMAC-SHA256.
    static func derive(
        password: String,
        salt: Data,
        iterations: Int = iterationCount,
        keyLength: Int = derivedKeyByteCount
    ) -> Data {
        let key = SymmetricKey(data: Data(password.utf8))
        let blockCount = Int((Double(keyLength) / Double(hashByteCount)).rounded(.up))

        var derived = Data()
        for blockIndex in 1...max(blockCount, 1) {
            derived.append(block(key: key, salt: salt, iterations: max(iterations, 1), blockIndex: blockIndex))
        }
        return derived.prefix(keyLength)
    }

    /// Compare deux `Data` en temps constant (par rapport a leur contenu, pas a leur
    /// longueur) : une comparaison naive (`==`) sortirait des ce premier octet
    /// different, ce qui expose en theorie une attaque par mesure de temps sur la
    /// verification du mot de passe. Defense en profondeur : le gain reel est faible
    /// ici (verification locale, pas un service reseau chronometrable a distance),
    /// mais le cout d'implementation est nul.
    static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (byteA, byteB) in zip(lhs, rhs) {
            difference |= byteA ^ byteB
        }
        return difference == 0
    }

    /// Un "bloc" de PBKDF2 : `F(password, salt, iterations, blockIndex)` selon RFC
    /// 8018 §5.2 - `U1 = HMAC(password, salt || BE32(blockIndex))`, puis
    /// `Ui = HMAC(password, U(i-1))`, le resultat etant le XOR cumule de tous les
    /// `Ui`.
    private static func block(key: SymmetricKey, salt: Data, iterations: Int, blockIndex: Int) -> Data {
        var salted = salt
        withUnsafeBytes(of: UInt32(blockIndex).bigEndian) { salted.append(contentsOf: $0) }

        var previous = Data(HMAC<SHA256>.authenticationCode(for: salted, using: key))
        var result = previous
        guard iterations > 1 else { return result }

        for _ in 2...iterations {
            previous = Data(HMAC<SHA256>.authenticationCode(for: previous, using: key))
            result = xor(result, previous)
        }
        return result
    }

    private static func xor(_ lhs: Data, _ rhs: Data) -> Data {
        Data(zip(lhs, rhs).map { $0 ^ $1 })
    }
}

import Foundation
import SlateModel

/// Erreurs de `LockService`. Volontairement peu nombreuses : la plupart des echecs
/// "attendus" (mauvais mot de passe, biometrie indisponible) sont representes par un
/// `Bool`/`false` de retour plutot que par une erreur, car ce sont des issues
/// normales d'un flux d'authentification, pas des anomalies.
public enum LockServiceError: Error, Sendable, Equatable {
    /// Le magasin de secret (Keychain en production) a refuse une ecriture ou une
    /// suppression necessaire a l'operation. Dans ce cas, l'operation n'a **aucun**
    /// effet partiel observable sur l'etat "mot de passe defini" : voir
    /// `setPassword(_:hint:allowBiometrics:)`.
    case secretStoreWriteFailed
}

/// Verrouillage de note au niveau de l'app, façon Notes d'Apple
/// (`docs/12_verrouillage.md`) : **un seul** mot de passe protege toutes les notes
/// verrouillees (pas un mot de passe par note), avec repli Touch ID/Face ID.
///
/// ## Ce que ce service protege, et ce qu'il ne protege pas
///
/// A dire honnetement a l'utilisateur (voir le rapport de cette tache pour le detail
/// de l'arbitrage) :
/// - **Protege contre** : un tiers qui a acces a l'app pendant que la session macOS de
///   l'utilisateur est deverrouillee (ecran partage, collegue de passage, enfant qui
///   utilise le Mac) et parcourt les notes/la recherche/la liste - le contenu d'une
///   note verrouillee n'apparait dans aucun de ces trois endroits. Ceci reste vrai
///   meme apres un arret brutal de l'app (plantage, `kill -9`, coupure de courant) :
///   `Note.isLocked` ne redevient jamais `false` en base, le deverrouillage n'etant
///   qu'un etat de session (`AppState.recentlyUnlockedNotes`) qui disparait avec le
///   processus - voir la documentation de tete de `Note`.
/// - **Ne protege PAS contre** : quelqu'un qui a acces au fichier du store SwiftData
///   lui-meme (disque demonte, sauvegarde Time Machine non chiffree, acces root sur la
///   machine) ou aux exports CloudKit cote serveur avec les identifiants iCloud de
///   l'utilisateur - le contenu des blocs n'est pas chiffre, seule son exposition par
///   l'UI/la recherche de l'app est controlee. Voir la note de securite en tete de
///   `Note` et le rapport de cette tache pour la justification de ce choix (FileVault
///   et le compte iCloud de l'utilisateur sont deja la ligne de defense pour ce
///   niveau de menace).
///
/// ## Stockage du secret
///
/// Le mot de passe lui-meme n'est **jamais** stocke, ni en clair ni chiffre : seul un
/// verificateur derive (sel aleatoire + PBKDF2-HMAC-SHA256, voir `PasswordHasher`) est
/// conserve dans le Keychain (`SecretStore`). Verifier un mot de passe consiste a le
/// re-deriver avec le meme sel et comparer au verificateur stocke - il n'existe aucune
/// operation inverse permettant de retrouver le mot de passe depuis ce qui est
/// enregistre.
public struct LockService: Sendable {
    private enum Keys {
        static let salt = "password.salt"
        static let verifier = "password.verifier"
        static let hint = "password.hint"
        static let biometricsAllowed = "password.biometricsAllowed"
    }

    private let secretStore: any SecretStore
    private let biometricAuthenticator: any BiometricAuthenticating

    public init(
        secretStore: any SecretStore = KeychainSecretStore(),
        biometricAuthenticator: any BiometricAuthenticating = SystemBiometricAuthenticator()
    ) {
        self.secretStore = secretStore
        self.biometricAuthenticator = biometricAuthenticator
    }

    // MARK: - Etat du mot de passe d'app

    /// Vrai si un mot de passe de verrouillage a deja ete defini.
    public var isPasswordSet: Bool {
        secretStore.read(key: Keys.salt) != nil && secretStore.read(key: Keys.verifier) != nil
    }

    /// Indice facultatif, volontairement lisible **sans authentification** : le
    /// design (artboard C) le montre sur l'ecran de deverrouillage, avant toute
    /// saisie. Ne jamais y stocker le mot de passe lui-meme (responsabilite de
    /// l'appelant/UI ; ce type ne fait que transporter la chaine fournie).
    public var passwordHint: String? {
        guard let data = secretStore.read(key: Keys.hint), let hint = String(data: data, encoding: .utf8) else {
            return nil
        }
        return hint
    }

    /// Vrai si l'utilisateur a autorise le repli Touch ID/Face ID pour le
    /// deverrouillage (reglage propose par le dialogue de definition du mot de
    /// passe). Independant de `isBiometricsAvailable` : ce dernier decrit une
    /// capacite materielle, celui-ci un choix utilisateur.
    public var isBiometricsAllowed: Bool {
        secretStore.read(key: Keys.biometricsAllowed) == Data([1])
    }

    /// Vrai si Touch ID/Face ID est disponible et configure sur cette machine. Sert a
    /// la regle de design : sans biometrie disponible, le bouton principal devient
    /// "Saisir le mot de passe" et le lien de repli disparait - jamais de bouton
    /// grise.
    public var isBiometricsAvailable: Bool {
        biometricAuthenticator.isBiometricsAvailable()
    }

    // MARK: - Definition / verification / suppression du mot de passe

    /// Definit (ou redefinit) le mot de passe de verrouillage de l'app. Ecrase tout
    /// mot de passe precedent : il n'y a jamais qu'un seul mot de passe actif.
    ///
    /// Si l'ecriture du sel ou du verificateur echoue, aucun des deux n'est laisse en
    /// place (nettoyage best-effort) et `LockServiceError.secretStoreWriteFailed` est
    /// leve : l'appelant ne doit jamais supposer un mot de passe defini si cette
    /// methode a leve une erreur.
    public func setPassword(_ password: String, hint: String? = nil, allowBiometrics: Bool = true) throws {
        let salt = PasswordHasher.randomSalt()
        let verifier = PasswordHasher.derive(password: password, salt: salt)

        guard secretStore.write(key: Keys.salt, value: salt), secretStore.write(key: Keys.verifier, value: verifier)
        else {
            secretStore.delete(key: Keys.salt)
            secretStore.delete(key: Keys.verifier)
            throw LockServiceError.secretStoreWriteFailed
        }

        let trimmedHint = hint?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedHint, !trimmedHint.isEmpty {
            secretStore.write(key: Keys.hint, value: Data(trimmedHint.utf8))
        } else {
            secretStore.delete(key: Keys.hint)
        }

        secretStore.write(key: Keys.biometricsAllowed, value: Data([allowBiometrics ? 1 : 0]))
    }

    /// Vrai si `password` correspond au mot de passe defini (re-derivation + une
    /// comparaison en temps constant, voir `PasswordHasher`). Retourne toujours
    /// `false`, jamais d'erreur, si aucun mot de passe n'est encore defini.
    public func verifyPassword(_ password: String) -> Bool {
        guard let salt = secretStore.read(key: Keys.salt), let expected = secretStore.read(key: Keys.verifier) else {
            return false
        }
        let candidate = PasswordHasher.derive(password: password, salt: salt)
        return PasswordHasher.constantTimeEquals(candidate, expected)
    }

    /// Supprime le mot de passe de verrouillage et tout ce qui lui est associe
    /// (indice, reglage biometrie). N'agit sur aucune note : desactiver le mot de
    /// passe d'app sans jamais avoir deverrouille les notes existantes laisserait
    /// des notes verrouillees sans plus aucun moyen de les deverrouiller - c'est a
    /// l'appelant (UI, phase future) d'imposer un deverrouillage prealable de toutes
    /// les notes avant d'autoriser cette action.
    public func removePassword() {
        secretStore.delete(key: Keys.salt)
        secretStore.delete(key: Keys.verifier)
        secretStore.delete(key: Keys.hint)
        secretStore.delete(key: Keys.biometricsAllowed)
    }

    // MARK: - Authentification biometrique

    /// Tente un deverrouillage par biometrie. Retourne `false` (sans lever d'erreur)
    /// si la biometrie n'est pas autorisee par l'utilisateur, pas disponible sur la
    /// machine, ou si l'authentification echoue/est annulee.
    public func authenticateWithBiometrics(reason: String) async -> Bool {
        guard isBiometricsAllowed, biometricAuthenticator.isBiometricsAvailable() else { return false }
        do {
            try await biometricAuthenticator.authenticate(reason: reason)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Verrouillage d'une note

    /// Verrouille `note` (voir `Note.lock()` : vide aussi `plainText`/`snippetText`).
    /// Ne demande aucune authentification - verrouiller n'a pas besoin d'etre
    /// protege, seul le deverrouillage l'est.
    @MainActor
    public func lock(_ note: Note) {
        note.lock()
    }

    // Il n'existe volontairement AUCUNE methode `unlock(_:...)` prenant une `Note` sur
    // ce type (dette de securite corrigee, voir STATUT.md phase 12) : deverrouiller ne
    // mute plus jamais `Note.isLocked`, qui reste vrai en permanence une fois la note
    // verrouillee. `verifyPassword(_:)` et `authenticateWithBiometrics(reason:)`
    // ci-dessus restent les deux seuls points d'authentification ; c'est a l'appelant
    // (`SlateFeatures.NoteDetailColumnView`) d'enregistrer le succes dans
    // `AppState.recentlyUnlockedNotes`, un etat de SESSION qui n'est jamais persiste ni
    // synchronise via CloudKit.
}

import Foundation
import SlateModel
import Testing

@testable import SlateServices

/// Revue de securite de `LockService` (Phase 12) : le secret n'est jamais stocke en
/// clair ni recuperable, un mot de passe correct valide/un mauvais echoue, le cycle
/// verrouiller/deverrouiller/re-verrouiller d'une note, et les bornes de la
/// disponibilite biometrique. Aucun test ici ne declenche de vraie interaction
/// biometrique (voir `FakeBiometricAuthenticator`).
@MainActor
struct LockServiceTests {

    private func makeService(
        store: any SecretStore = InMemorySecretStore(),
        biometrics: FakeBiometricAuthenticator = FakeBiometricAuthenticator()
    ) -> LockService {
        LockService(secretStore: store, biometricAuthenticator: biometrics)
    }

    // MARK: - Stockage du secret

    @Test
    func noPasswordSetInitially() {
        let service = makeService()
        #expect(!service.isPasswordSet)
        #expect(!service.verifyPassword("anything"))
    }

    @Test
    func settingAPasswordNeverStoresItInClearInTheUnderlyingStore() throws {
        let store = InMemorySecretStore()
        let service = makeService(store: store)
        let password = "CorrectHorse!42"

        try service.setPassword(password)

        let salt = store.read(key: "password.salt")
        let verifier = store.read(key: "password.verifier")
        #expect(salt != nil)
        #expect(verifier != nil)

        // Rien de ce qui est stocke n'est le mot de passe lui-meme : ni le sel, ni le
        // verificateur derive, ne doivent correspondre aux octets bruts du mot de
        // passe.
        let passwordBytes = Data(password.utf8)
        #expect(salt != passwordBytes)
        #expect(verifier != passwordBytes)

        // Le verificateur a la taille d'une cle derivee (32 octets), pas celle d'un
        // mot de passe stocke tel quel.
        #expect(verifier?.count == PasswordHasher.derivedKeyByteCount)
    }

    @Test
    func thereIsNoWayToReadBackThePasswordOnlyToVerifyAProposal() throws {
        // Ce test documente une propriete d'API : `LockService` n'expose aucune
        // methode retournant le mot de passe en clair, seulement `verifyPassword`
        // (booleen) et `passwordHint` (indice facultatif distinct du mot de passe).
        // Une regression qui ajouterait une telle methode romprait cette garantie.
        let service = makeService()
        try service.setPassword("CorrectHorse!42", hint: "Un indice")

        #expect(service.passwordHint == "Un indice")
        #expect(service.verifyPassword("CorrectHorse!42"))
        // `passwordHint` ne doit jamais etre confondu avec le mot de passe.
        #expect(service.passwordHint != "CorrectHorse!42")
    }

    @Test
    func correctPasswordVerifies() throws {
        let service = makeService()
        try service.setPassword("CorrectHorse!42")
        #expect(service.verifyPassword("CorrectHorse!42"))
    }

    @Test
    func incorrectPasswordFails() throws {
        let service = makeService()
        try service.setPassword("CorrectHorse!42")
        #expect(!service.verifyPassword("WrongPassword"))
    }

    @Test
    func emptyPasswordDoesNotAccidentallyVerify() throws {
        let service = makeService()
        try service.setPassword("CorrectHorse!42")
        #expect(!service.verifyPassword(""))
    }

    @Test
    func settingANewPasswordInvalidatesThePreviousOne() throws {
        let service = makeService()
        try service.setPassword("FirstPassword!1")
        try service.setPassword("SecondPassword!2")

        #expect(!service.verifyPassword("FirstPassword!1"))
        #expect(service.verifyPassword("SecondPassword!2"))
    }

    @Test
    func hintIsVisibleBeforeAnyAuthentication() throws {
        let service = makeService()
        #expect(service.passwordHint == nil)

        try service.setPassword("CorrectHorse!42", hint: "  Mon indice  ")
        #expect(service.passwordHint == "Mon indice")
    }

    @Test
    func blankHintIsTreatedAsNoHint() throws {
        let service = makeService()
        try service.setPassword("CorrectHorse!42", hint: "   ")
        #expect(service.passwordHint == nil)
    }

    @Test
    func removingThePasswordClearsVerificationAndHint() throws {
        let service = makeService()
        try service.setPassword("CorrectHorse!42", hint: "Indice")

        service.removePassword()

        #expect(!service.isPasswordSet)
        #expect(service.passwordHint == nil)
        #expect(!service.verifyPassword("CorrectHorse!42"))
    }

    @Test
    func setPasswordThrowsAndLeavesNoPartialStateWhenSecretStoreFails() {
        let service = makeService(store: FailingSecretStore())
        #expect(throws: LockServiceError.secretStoreWriteFailed) {
            try service.setPassword("CorrectHorse!42")
        }
        #expect(!service.isPasswordSet)
    }

    // MARK: - Biometrie

    @Test
    func biometricsUnavailableOnTheDeviceIsReportedAsUnavailable() {
        let biometrics = FakeBiometricAuthenticator()
        biometrics.available = false
        let service = makeService(biometrics: biometrics)

        #expect(!service.isBiometricsAvailable)
    }

    @Test
    func biometricsNotAllowedByUserNeverAuthenticatesEvenIfDeviceSupportsIt() async throws {
        let biometrics = FakeBiometricAuthenticator()
        biometrics.available = true
        biometrics.succeeds = true
        let service = makeService(biometrics: biometrics)
        try service.setPassword("CorrectHorse!42", allowBiometrics: false)

        #expect(!service.isBiometricsAllowed)
        #expect(await service.authenticateWithBiometrics(reason: "Test") == false)
    }

    @Test
    func biometricsAllowedAndAvailableAndSucceedingAuthenticates() async throws {
        let biometrics = FakeBiometricAuthenticator()
        biometrics.available = true
        biometrics.succeeds = true
        let service = makeService(biometrics: biometrics)
        try service.setPassword("CorrectHorse!42", allowBiometrics: true)

        #expect(await service.authenticateWithBiometrics(reason: "Test") == true)
    }

    @Test
    func biometricsFailureIsReportedAsFalseNotAsAThrownError() async throws {
        let biometrics = FakeBiometricAuthenticator()
        biometrics.available = true
        biometrics.succeeds = false
        let service = makeService(biometrics: biometrics)
        try service.setPassword("CorrectHorse!42", allowBiometrics: true)

        #expect(await service.authenticateWithBiometrics(reason: "Test") == false)
    }

    // MARK: - Cycle verrouiller / deverrouiller une note

    @Test
    func lockingANoteDoesNotRequireAuthentication() throws {
        let service = makeService()
        let note = Note(title: "Confidentiel")
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: "Secret."), note: note)]
        note.refreshDerivedText()

        service.lock(note)

        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
    }

    @Test
    func unlockingANoteWithTheCorrectPasswordRevealsItsContent() throws {
        let service = makeService()
        try service.setPassword("CorrectHorse!42")
        let note = Note(title: "Confidentiel")
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: "Secret."), note: note)]
        note.refreshDerivedText()
        service.lock(note)

        let unlocked = service.unlock(note, password: "CorrectHorse!42")

        #expect(unlocked)
        #expect(!note.isLocked)
        #expect(note.plainText == "Secret.")
    }

    @Test
    func unlockingANoteWithTheWrongPasswordLeavesItLocked() throws {
        let service = makeService()
        try service.setPassword("CorrectHorse!42")
        let note = Note(title: "Confidentiel", isLocked: true)

        let unlocked = service.unlock(note, password: "WrongPassword")

        #expect(!unlocked)
        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
    }

    @Test
    func unlockingANoteWithBiometricsRevealsItsContentOnSuccess() async throws {
        let biometrics = FakeBiometricAuthenticator()
        biometrics.available = true
        biometrics.succeeds = true
        let service = makeService(biometrics: biometrics)
        try service.setPassword("CorrectHorse!42", allowBiometrics: true)
        let note = Note(title: "Confidentiel")
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: "Secret."), note: note)]
        note.refreshDerivedText()
        service.lock(note)

        let unlocked = await service.unlock(note, usingBiometricsReason: "Test")

        #expect(unlocked)
        #expect(!note.isLocked)
        #expect(note.plainText == "Secret.")
    }

    @Test
    func unlockingANoteWithBiometricsLeavesItLockedOnFailure() async throws {
        let biometrics = FakeBiometricAuthenticator()
        biometrics.available = true
        biometrics.succeeds = false
        let service = makeService(biometrics: biometrics)
        try service.setPassword("CorrectHorse!42", allowBiometrics: true)
        let note = Note(title: "Confidentiel", isLocked: true)

        let unlocked = await service.unlock(note, usingBiometricsReason: "Test")

        #expect(!unlocked)
        #expect(note.isLocked)
    }

    @Test
    func lockUnlockRelockCycleThroughTheServiceIsConsistent() throws {
        let service = makeService()
        try service.setPassword("CorrectHorse!42")
        let note = Note(title: "Confidentiel")
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: "Secret."), note: note)]
        note.refreshDerivedText()

        service.lock(note)
        #expect(note.plainText.isEmpty)

        #expect(service.unlock(note, password: "CorrectHorse!42"))
        #expect(note.plainText == "Secret.")

        service.lock(note)
        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
    }
}

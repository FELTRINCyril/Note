import Foundation
import Testing

@testable import SlateServices

/// Verifie la correction de `PasswordHasher` contre des vecteurs de reference
/// PBKDF2-HMAC-SHA256 generes independamment avec `hashlib.pbkdf2_hmac` (Python), afin
/// de ne pas se fier uniquement a une auto-coherence de l'implementation : une erreur
/// de derivation qui resterait auto-coherente (meme entree -> meme sortie, a chaque
/// fois) passerait inapercue sans comparaison a une implementation de reference
/// independante.
struct PasswordHasherTests {

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    @Test
    func matchesReferenceVectorForOneIteration() {
        let derived = PasswordHasher.derive(
            password: "password", salt: Data("salt".utf8), iterations: 1, keyLength: 32
        )
        #expect(hex(derived) == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
    }

    @Test
    func matchesReferenceVectorForTwoIterations() {
        let derived = PasswordHasher.derive(
            password: "password", salt: Data("salt".utf8), iterations: 2, keyLength: 32
        )
        #expect(hex(derived) == "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43")
    }

    @Test
    func matchesReferenceVectorForFourThousandNinetySixIterations() {
        let derived = PasswordHasher.derive(
            password: "password", salt: Data("salt".utf8), iterations: 4_096, keyLength: 32
        )
        #expect(hex(derived) == "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")
    }

    @Test
    func sameInputsProduceSameOutput() {
        let salt = PasswordHasher.randomSalt()
        let first = PasswordHasher.derive(password: "CorrectHorse!42", salt: salt)
        let second = PasswordHasher.derive(password: "CorrectHorse!42", salt: salt)
        #expect(first == second)
    }

    @Test
    func differentPasswordsProduceDifferentOutputs() {
        let salt = PasswordHasher.randomSalt()
        let first = PasswordHasher.derive(password: "CorrectHorse!42", salt: salt)
        let second = PasswordHasher.derive(password: "IncorrectHorse!42", salt: salt)
        #expect(first != second)
    }

    @Test
    func differentSaltsProduceDifferentOutputsForSamePassword() {
        let first = PasswordHasher.derive(password: "CorrectHorse!42", salt: PasswordHasher.randomSalt())
        let second = PasswordHasher.derive(password: "CorrectHorse!42", salt: PasswordHasher.randomSalt())
        #expect(first != second)
    }

    @Test
    func randomSaltIsNotTriviallyRepeated() {
        let salts = (0..<20).map { _ in PasswordHasher.randomSalt() }
        #expect(Set(salts).count == salts.count)
    }

    @Test
    func constantTimeEqualsMatchesEqualData() {
        let value = Data([1, 2, 3, 4])
        #expect(PasswordHasher.constantTimeEquals(value, value))
    }

    @Test
    func constantTimeEqualsRejectsDifferentData() {
        #expect(!PasswordHasher.constantTimeEquals(Data([1, 2, 3, 4]), Data([1, 2, 3, 5])))
    }

    @Test
    func constantTimeEqualsRejectsDifferentLengths() {
        #expect(!PasswordHasher.constantTimeEquals(Data([1, 2, 3]), Data([1, 2, 3, 4])))
    }
}

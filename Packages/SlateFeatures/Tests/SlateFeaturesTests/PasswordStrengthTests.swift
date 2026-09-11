import Testing
@testable import SlateFeatures

/// Robustesse heuristique de `PasswordStrength.evaluate(_:)` (Phase 12,
/// `docs/12_verrouillage.md`).
@Suite("PasswordStrength")
struct PasswordStrengthTests {
    @Test("Mot de passe vide : faible")
    func emptyIsWeak() {
        #expect(PasswordStrength.evaluate("") == .weak)
    }

    @Test("Court : faible")
    func shortIsWeak() {
        #expect(PasswordStrength.evaluate("abcd") == .weak)
    }

    @Test("Long mais d'une seule categorie : moyen, pas robuste (la longueur seule ne suffit pas)")
    func longSingleCategoryIsMediumNotStrong() {
        #expect(PasswordStrength.evaluate("aaaaaaaaaaaaaa") == .medium)
    }

    @Test("Longueur moyenne avec deux categories : moyen")
    func mediumLengthMixedCategoriesIsMedium() {
        #expect(PasswordStrength.evaluate("abcdef12") == .medium)
    }

    @Test("Long avec au moins deux categories : robuste")
    func longMixedCategoriesIsStrong() {
        #expect(PasswordStrength.evaluate("abcdefghij12") == .strong)
        #expect(PasswordStrength.evaluate("Tr0ub4dor&3!!") == .strong)
    }

    @Test("Longueur seule (une categorie) ne suffit pas a la robustesse maximale")
    func lengthAloneIsNotEnoughForStrong() {
        #expect(PasswordStrength.evaluate("aaaaaaaaaaaaaaaa") != .strong)
    }
}

import Testing
@testable import SlateUI

@Suite("Tokens SlateUI")
struct SlateUITests {
    @Test("L'echelle d'espacement est strictement croissante")
    func spacingScaleIsIncreasing() {
        let scale = [Spacing.xs, Spacing.sm, Spacing.md, Spacing.lg, Spacing.xl]
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
    }

    @Test("L'espacement de base est un multiple de 4pt")
    func spacingIsOnFourPointGrid() {
        #expect(Spacing.xs == 4)
        #expect(Spacing.sm == 8)
        #expect(Spacing.md == 12)
        #expect(Spacing.lg == 16)
        #expect(Spacing.xl == 24)
    }
}

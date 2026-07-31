import Testing
@testable import SlateFeatures

@Suite("Placeholder SlateFeatures")
struct SlateFeaturesTests {
    @Test("Le module est bien lie")
    func moduleIsLinked() {
        #expect(SlateFeatures.placeholderVersion == 1)
    }
}

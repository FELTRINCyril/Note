import Testing
@testable import SlateServices

@Suite("Placeholder SlateServices")
struct SlateServicesTests {
    @Test("Le module est bien lie")
    func moduleIsLinked() {
        #expect(SlateServices.placeholderVersion == 1)
    }
}

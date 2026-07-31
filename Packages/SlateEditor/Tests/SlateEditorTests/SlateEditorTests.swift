import Testing
@testable import SlateEditor

@Suite("Placeholder SlateEditor")
struct SlateEditorTests {
    @Test("Le module est bien lie")
    func moduleIsLinked() {
        #expect(SlateEditor.placeholderVersion == 1)
    }
}

import XCTest

/// Audit des liens internes (Phase 16, `docs/16_liens_internes.md`) : taper "@" doit
/// ouvrir le selecteur de pages.
@MainActor
final class SlateInternalLinksUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testTypingAtSignOpensPageMentionPicker() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        // Cree une premiere note "cible", pour qu'il existe au moins une page a
        // proposer dans le selecteur.
        guard SlateUITestSupport.openFreshNote(folderPrefix: "Audit Lien Cible", in: app, testCase: self) != nil else {
            XCTFail("Impossible de preparer une note cible pour le selecteur de pages.")
            return
        }

        guard let body = SlateUITestSupport.openFreshNote(folderPrefix: "Audit Lien Source", in: app, testCase: self) else {
            XCTFail("Impossible d'ouvrir une note source pour tester '@'.")
            return
        }

        body.typeText("Voir aussi @")
        Thread.sleep(forTimeInterval: 0.7)
        SlateUITestSupport.capture(window, named: "60-selecteur-de-pages-apres-arobase", in: self)

        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }
}

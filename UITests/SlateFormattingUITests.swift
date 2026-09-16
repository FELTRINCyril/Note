import XCTest

/// Audit du formatage de texte selectionne (Phase 7, `docs/07_typographie_formatage.md`) :
/// selection, Cmd+B / Cmd+I, barre de formatage flottante.
@MainActor
final class SlateFormattingUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testSelectionShowsFloatingFormatBarAndBoldItalicShortcuts() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        guard let body = SlateUITestSupport.openFreshNote(folderPrefix: "Audit Formatage", in: app, testCase: self) else {
            XCTFail("Impossible d'ouvrir une note fraiche pour tester le formatage.")
            return
        }

        body.typeText("Texte a mettre en forme")
        // Selectionne tout le contenu du bloc courant (le focus clavier reste dans le
        // NSTextView du bloc, Cmd+A n'agit donc pas sur toute la note).
        body.typeKey("a", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)
        SlateUITestSupport.capture(window, named: "40-texte-selectionne", in: self)

        let boldButton = app.buttons["Gras"]
        let italicButton = app.buttons["Italique"]
        let barIsVisible = boldButton.waitForExistence(timeout: 3)
        XCTAssertTrue(barIsVisible, "La barre de formatage flottante (bouton 'Gras') n'apparait pas apres selection.")
        XCTAssertTrue(italicButton.exists, "Le bouton 'Italique' de la barre de formatage est introuvable.")

        body.typeKey("b", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)
        SlateUITestSupport.capture(window, named: "41-apres-cmd-b", in: self)

        body.typeKey("i", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.3)
        SlateUITestSupport.capture(window, named: "42-apres-cmd-i", in: self)
    }
}

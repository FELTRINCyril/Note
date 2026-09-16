import XCTest

/// Audit du markdown a la frappe (Phase 15, `docs/15_markdown_frappe.md`) : "# ",
/// "- ", "[] ", "> " doivent convertir le bloc courant a l'espace tapee.
///
/// Chaque cas repart d'un bloc neuf (note fraiche) : la conversion consomme le
/// marqueur, donc la seule verification fiable sans inspecter le modele est visuelle
/// (capture) -- ces tests capturent systematiquement et n'assertent que la survie de
/// l'app (pas de crash), le reste est un constat de lecture d'image.
@MainActor
final class SlateMarkdownShortcutsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testHeadingMarkdownShortcut() throws {
        try runMarkdownShortcut(typed: "# Titre par markdown", captureName: "50-markdown-titre")
    }

    func testBulletListMarkdownShortcut() throws {
        try runMarkdownShortcut(typed: "- Element de liste par markdown", captureName: "51-markdown-liste")
    }

    func testCheckboxMarkdownShortcut() throws {
        try runMarkdownShortcut(typed: "[] Tache par markdown", captureName: "52-markdown-checkbox")
    }

    func testQuoteMarkdownShortcut() throws {
        try runMarkdownShortcut(typed: "> Citation par markdown", captureName: "53-markdown-citation")
    }

    private func runMarkdownShortcut(typed text: String, captureName: String) throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        guard let body = SlateUITestSupport.openFreshNote(
            folderPrefix: "Audit Markdown \(captureName)",
            in: app,
            testCase: self
        ) else {
            XCTFail("Impossible d'ouvrir une note fraiche pour tester '\(text)'.")
            return
        }

        body.typeText(text)
        Thread.sleep(forTimeInterval: 0.5)
        SlateUITestSupport.capture(window, named: captureName, in: self)
    }
}

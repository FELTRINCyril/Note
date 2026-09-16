import XCTest

/// Audit des bases de donnees (Phase 17, `docs/17_base_de_donnees.md`) : creation
/// d'une base pleine page, grille par defaut, bascule entre vues.
@MainActor
final class SlateDatabaseUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testCreateDatabaseAndSwitchViews() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        let folderName = "Audit Base \(uniqueSuffix)"
        guard SlateUITestSupport.createFolder(named: folderName, in: app, testCase: self),
              SlateUITestSupport.selectFolder(named: folderName, in: app) else {
            XCTFail("Impossible de preparer un dossier pour tester les bases de donnees.")
            return
        }

        let newDatabaseButton = app.buttons["Nouvelle base"]
        guard newDatabaseButton.waitForExistence(timeout: 5) else {
            XCTFail("Bouton 'Nouvelle base' introuvable dans la liste de notes.")
            return
        }
        newDatabaseButton.click()
        Thread.sleep(forTimeInterval: 1.5)
        SlateUITestSupport.capture(window, named: "90-base-creee-vue-grille", in: self)

        for viewName in ["Liste", "Kanban", "Calendrier", "Galerie"] {
            let viewButton = app.buttons[viewName]
            guard viewButton.waitForExistence(timeout: 3) else {
                XCTFail("Bouton de bascule de vue introuvable : \(viewName)")
                continue
            }
            viewButton.click()
            Thread.sleep(forTimeInterval: 1)
            SlateUITestSupport.capture(window, named: "91-base-vue-\(viewName)", in: self)
        }

        let gridButton = app.buttons["Grille"]
        if gridButton.waitForExistence(timeout: 3) {
            gridButton.click()
        }
    }

    private var uniqueSuffix: String {
        String(Int(Date().timeIntervalSince1970))
    }
}

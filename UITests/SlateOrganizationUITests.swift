import XCTest

/// Audit de l'organisation des notes (Phase 11, `docs/11_organisation.md`) : menu
/// contextuel sur une note, corbeille.
@MainActor
final class SlateOrganizationUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testNoteContextMenuEntries() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        let folderName = "Audit Organisation \(uniqueSuffix)"
        guard SlateUITestSupport.createFolder(named: folderName, in: app, testCase: self),
              SlateUITestSupport.selectFolder(named: folderName, in: app) else {
            XCTFail("Impossible de preparer un dossier pour tester le menu contextuel de note.")
            return
        }

        let newNoteButton = SlateUITestSupport.sidebarNewNoteButton(in: app)
        XCTAssertTrue(newNoteButton.waitForExistence(timeout: 5))
        newNoteButton.click()
        Thread.sleep(forTimeInterval: 1)

        let noteCell = SlateUITestSupport.noteCell(titled: "Nouvelle note", in: app)
        guard noteCell.waitForExistence(timeout: 5) else {
            XCTFail("Cellule de note introuvable dans la liste pour le clic droit.")
            return
        }
        noteCell.rightClick()
        SlateUITestSupport.capture(window, named: "70-menu-contextuel-note", in: self)

        for expected in ["Épingler", "Dupliquer", "Verrouiller la note", "Mettre à la corbeille"] {
            XCTAssertTrue(
                app.menuItems[expected].waitForExistence(timeout: 3),
                "Entree de menu contextuel de note manquante : \(expected)"
            )
        }
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    func testMoveNoteToTrashAndOpenTrash() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        let folderName = "Audit Corbeille \(uniqueSuffix)"
        guard SlateUITestSupport.createFolder(named: folderName, in: app, testCase: self),
              SlateUITestSupport.selectFolder(named: folderName, in: app) else {
            XCTFail("Impossible de preparer un dossier pour tester la corbeille.")
            return
        }

        let newNoteButton = SlateUITestSupport.sidebarNewNoteButton(in: app)
        XCTAssertTrue(newNoteButton.waitForExistence(timeout: 5))
        newNoteButton.click()
        Thread.sleep(forTimeInterval: 1)

        let noteCell = SlateUITestSupport.noteCell(titled: "Nouvelle note", in: app)
        guard noteCell.waitForExistence(timeout: 5) else {
            XCTFail("Cellule de note introuvable, mise a la corbeille non testee.")
            return
        }
        noteCell.rightClick()
        let trashItem = app.menuItems["Mettre à la corbeille"]
        guard trashItem.waitForExistence(timeout: 3) else {
            XCTFail("Entree 'Mettre à la corbeille' introuvable.")
            return
        }
        trashItem.click()
        Thread.sleep(forTimeInterval: 1)
        SlateUITestSupport.capture(window, named: "71-apres-mise-a-la-corbeille", in: self)

        let trashButton = app.buttons["Corbeille"]
        XCTAssertTrue(trashButton.waitForExistence(timeout: 5))
        trashButton.click()
        Thread.sleep(forTimeInterval: 1)
        SlateUITestSupport.capture(window, named: "72-fenetre-corbeille", in: self)

        XCTAssertTrue(app.staticTexts["Corbeille"].waitForExistence(timeout: 5), "Le titre 'Corbeille' n'apparait pas dans la feuille.")
    }

    private var uniqueSuffix: String {
        String(Int(Date().timeIntervalSince1970))
    }
}

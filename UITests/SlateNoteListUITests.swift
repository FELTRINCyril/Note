import XCTest

/// Audit de la liste de notes (Phase 4, `docs/04_liste_notes.md`) : creation, regroupement
/// temporel, apercu de contenu, epinglage.
@MainActor
final class SlateNoteListUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    /// Cree un dossier dedie, y cree une note, verifie l'apparition dans la liste.
    func testCreatingANoteShowsItInTheList() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        let folderName = "Audit Liste \(uniqueSuffix)"
        guard SlateUITestSupport.createFolder(named: folderName, in: app, testCase: self),
              SlateUITestSupport.selectFolder(named: folderName, in: app) else {
            XCTFail("Impossible de preparer un dossier pour tester la liste de notes.")
            return
        }

        SlateUITestSupport.capture(window, named: "20-dossier-vide", in: self)

        let newNoteButton = SlateUITestSupport.sidebarNewNoteButton(in: app)
        XCTAssertTrue(newNoteButton.waitForExistence(timeout: 5))
        XCTAssertTrue(newNoteButton.isEnabled, "Le bouton Nouvelle note reste desactive alors qu'un dossier est selectionne.")
        newNoteButton.click()
        Thread.sleep(forTimeInterval: 1)

        SlateUITestSupport.capture(window, named: "21-note-creee-dans-la-liste", in: self)

        XCTAssertTrue(
            SlateUITestSupport.noteCell(titled: "Nouvelle note", in: app).waitForExistence(timeout: 5),
            "La note nouvellement creee n'apparait pas (titre par defaut 'Nouvelle note')."
        )
    }

    /// Deuxieme note dans le meme dossier : verifie que la liste regroupe/empile
    /// correctement plusieurs notes (regroupement par date, spec E3).
    func testMultipleNotesAndDateGrouping() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        let folderName = "Audit Groupes \(uniqueSuffix)"
        guard SlateUITestSupport.createFolder(named: folderName, in: app, testCase: self),
              SlateUITestSupport.selectFolder(named: folderName, in: app) else {
            XCTFail("Impossible de preparer un dossier pour tester le regroupement.")
            return
        }

        let newNoteButton = SlateUITestSupport.sidebarNewNoteButton(in: app)
        for _ in 0..<2 {
            XCTAssertTrue(newNoteButton.waitForExistence(timeout: 5))
            newNoteButton.click()
            Thread.sleep(forTimeInterval: 1)
        }

        SlateUITestSupport.capture(window, named: "22-deux-notes-regroupement-date", in: self)

        // Spec E3 : groupe "Aujourd'hui" attendu pour des notes creees a l'instant.
        XCTAssertTrue(
            app.staticTexts["Aujourd'hui"].exists,
            "Aucun en-tete de groupe de date 'Aujourd'hui' trouve pour des notes fraichement creees."
        )
    }

    private var uniqueSuffix: String {
        String(Int(Date().timeIntervalSince1970))
    }
}

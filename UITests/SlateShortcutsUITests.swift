import XCTest

/// Audit des raccourcis clavier globaux (Phase 14, `docs/14_raccourcis_clavier.md`) :
/// Cmd+N, Ctrl+Cmd+1/2/3 (deplacement de focus de panneau), barre de menus.
@MainActor
final class SlateShortcutsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testCommandNCreatesNoteViaKeyboard() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        let folderName = "Audit Raccourcis \(uniqueSuffix)"
        guard SlateUITestSupport.createFolder(named: folderName, in: app, testCase: self),
              SlateUITestSupport.selectFolder(named: folderName, in: app) else {
            XCTFail("Impossible de preparer un dossier pour tester Cmd+N.")
            return
        }

        window.typeKey("n", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1)
        SlateUITestSupport.capture(window, named: "A0-apres-cmd-n", in: self)

        XCTAssertTrue(
            SlateUITestSupport.noteCell(titled: "Nouvelle note", in: app).waitForExistence(timeout: 5),
            "Cmd+N ne semble pas avoir cree de note dans le dossier selectionne."
        )
    }

    /// Focus de panneau (Phase 14) : Ctrl+Cmd+1 (sidebar), Ctrl+Cmd+2 (liste),
    /// Ctrl+Cmd+3 (editeur). Verifie seulement l'absence de crash et capture l'etat
    /// visuel -- le focus clavier reel n'est pas directement lisible par assertion sans
    /// inspecter `AXFocused`, ce que XCUITest n'expose pas de facon fiable pour des
    /// vues SwiftUI personnalisees.
    func testFocusPanelShortcuts() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        window.typeKey("1", modifierFlags: [.control, .command])
        Thread.sleep(forTimeInterval: 0.5)
        SlateUITestSupport.capture(window, named: "A1-focus-ctrl-cmd-1-sidebar", in: self)

        window.typeKey("2", modifierFlags: [.control, .command])
        Thread.sleep(forTimeInterval: 0.5)
        SlateUITestSupport.capture(window, named: "A2-focus-ctrl-cmd-2-liste", in: self)

        window.typeKey("3", modifierFlags: [.control, .command])
        Thread.sleep(forTimeInterval: 0.5)
        SlateUITestSupport.capture(window, named: "A3-focus-ctrl-cmd-3-editeur", in: self)
    }

    /// Barre de menus complete (Fichier/Edition/Format/Affichage), au-dela de ce que
    /// `SlateLaunchUITests.testMenuBarExposesExpectedCommands` verifie deja.
    ///
    /// Le menu "Affichage" de `SlateAppCommands` (`CommandGroup(after: .sidebar)`)
    /// s'attache au menu SYSTEME "View" de macOS, dont le titre localise en francais est
    /// "Présentation" -- pas "Affichage" (verifie sur l'app reelle). Attendre "Affichage"
    /// ici serait une hypothese fausse, pas un defaut de l'app.
    func testFullMenuBarStructure() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 10))

        let titles = menuBar.menuBarItems.allElementsBoundByIndex.map { $0.title }
        SlateUITestSupport.capture(app.windows.firstMatch, named: "A4-fenetre-avant-inspection-menus", in: self)

        for expected in ["Fichier", "Édition", "Présentation", "Format"] {
            XCTAssertTrue(titles.contains(expected), "Menu manquant : \(expected). Vus : \(titles)")
        }

        let presentation = menuBar.menuBarItems["Présentation"]
        presentation.click()
        let presentationItems = presentation.menuItems.allElementsBoundByIndex.map { $0.title }
        presentation.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        for expected in [
            "Afficher/masquer la barre latérale",
            "Afficher/masquer la liste",
            "Mode focus"
        ] {
            XCTAssertTrue(
                presentationItems.contains(expected),
                "Entree de menu Presentation manquante ou differente : \(expected). Vues : \(presentationItems)"
            )
        }
    }

    private var uniqueSuffix: String {
        String(Int(Date().timeIntervalSince1970))
    }
}

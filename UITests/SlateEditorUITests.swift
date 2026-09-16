import XCTest

/// Audit de l'editeur de blocs (Phases 5-8, `docs/05_editeur_blocs.md` et suivants) :
/// frappe simple, Entree, menu "/" et ses commandes.
///
/// Chaque test repart d'un dossier/note neufs (`SlateUITestSupport.openFreshNote`) :
/// un blocage sur une commande n'empeche donc pas de tester les suivantes.
@MainActor
final class SlateEditorUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testTypingTextAndPressingReturn() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        guard let body = SlateUITestSupport.openFreshNote(folderPrefix: "Audit Editeur Frappe", in: app, testCase: self) else {
            XCTFail("Impossible d'ouvrir une note fraiche pour tester la frappe.")
            return
        }

        body.typeText("Bonjour Slate, ceci est un test d'audit.")
        SlateUITestSupport.capture(window, named: "30-editeur-texte-tape", in: self)

        body.typeText("\n")
        body.typeText("Deuxieme paragraphe, cree par la touche Entree.")
        SlateUITestSupport.capture(window, named: "31-editeur-apres-retour-chariot", in: self)

        XCTAssertTrue(
            app.staticTexts["Bonjour Slate, ceci est un test d'audit."].exists
                || app.textViews["Bonjour Slate, ceci est un test d'audit."].exists,
            "Le texte tape ne semble pas persiste/affiche dans le bloc."
        )
    }

    func testSlashMenuOpensAndListsCommands() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        guard let body = SlateUITestSupport.openFreshNote(folderPrefix: "Audit Slash Menu", in: app, testCase: self) else {
            XCTFail("Impossible d'ouvrir une note fraiche pour tester le menu /.")
            return
        }

        body.typeText("/")
        Thread.sleep(forTimeInterval: 0.5)
        SlateUITestSupport.capture(window, named: "32-menu-slash-ouvert", in: self)

        for expectedTitle in ["Titre 1", "Liste à puces", "Liste de tâches", "Citation", "Code", "Encadré", "Tableau"] {
            let predicate = NSPredicate(format: "label BEGINSWITH[c] %@", expectedTitle)
            let item = app.buttons.matching(predicate).firstMatch
            XCTAssertTrue(item.exists, "Commande de menu / introuvable : \(expectedTitle)")
        }
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    func testSlashCreatesHeading() throws {
        try runSlashCommand(commandTitle: "Titre 1", typedAfter: "Un titre de niveau 1", captureName: "33-bloc-titre")
    }

    func testSlashCreatesBulletedList() throws {
        try runSlashCommand(commandTitle: "Liste à puces", typedAfter: "Premier element de liste", captureName: "34-bloc-liste-a-puces")
    }

    func testSlashCreatesTodo() throws {
        try runSlashCommand(commandTitle: "Liste de tâches", typedAfter: "Une tache a cocher", captureName: "35-bloc-case-a-cocher")
    }

    func testSlashCreatesQuote() throws {
        try runSlashCommand(commandTitle: "Citation", typedAfter: "Une citation exemplaire", captureName: "36-bloc-citation")
    }

    func testSlashCreatesCodeBlock() throws {
        try runSlashCommand(commandTitle: "Code", typedAfter: "let x = 42", captureName: "37-bloc-code")
    }

    func testSlashCreatesCallout() throws {
        try runSlashCommand(commandTitle: "Encadré", typedAfter: "Une remarque importante", captureName: "38-bloc-encadre")
    }

    func testSlashCreatesTable() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        guard let body = SlateUITestSupport.openFreshNote(folderPrefix: "Audit Slash Tableau", in: app, testCase: self) else {
            XCTFail("Impossible d'ouvrir une note fraiche pour tester la commande Tableau.")
            return
        }

        body.typeText("/tableau")
        Thread.sleep(forTimeInterval: 0.5)
        SlateUITestSupport.capture(window, named: "39a-slash-filtre-tableau", in: self)

        let predicate = NSPredicate(format: "label BEGINSWITH[c] %@", "Tableau")
        let item = app.buttons.matching(predicate).firstMatch
        guard item.waitForExistence(timeout: 3) else {
            XCTFail("Commande 'Tableau' introuvable apres filtrage du menu /.")
            return
        }
        item.click()
        Thread.sleep(forTimeInterval: 1)
        SlateUITestSupport.capture(window, named: "39-bloc-tableau", in: self)
    }

    /// Ouvre une note fraiche, tape "/" + tape le titre de la commande pour filtrer,
    /// clique la premiere correspondance, tape du texte dans le bloc resultant, capture.
    private func runSlashCommand(commandTitle: String, typedAfter text: String, captureName: String) throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        guard let body = SlateUITestSupport.openFreshNote(
            folderPrefix: "Audit Slash \(commandTitle)",
            in: app,
            testCase: self
        ) else {
            XCTFail("Impossible d'ouvrir une note fraiche pour tester la commande '\(commandTitle)'.")
            return
        }

        body.typeText("/")
        Thread.sleep(forTimeInterval: 0.5)

        let predicate = NSPredicate(format: "label BEGINSWITH[c] %@", commandTitle)
        let item = app.buttons.matching(predicate).firstMatch
        guard item.waitForExistence(timeout: 3) else {
            XCTFail("Commande '\(commandTitle)' introuvable dans le menu /.")
            SlateUITestSupport.capture(window, named: "\(captureName)-ECHEC-commande-introuvable", in: self)
            return
        }
        item.click()
        Thread.sleep(forTimeInterval: 0.5)
        app.typeText(text)
        Thread.sleep(forTimeInterval: 0.3)
        SlateUITestSupport.capture(window, named: captureName, in: self)
    }
}

import XCTest

/// Tests d'interface : ils lancent Slate POUR DE VRAI et la pilotent.
///
/// Pourquoi ils existent : ce projet a 17 phases livrees sans que rien n'ait jamais
/// ete vu a l'ecran. Les tests de rendu de `SlateUI` (`Snapshots/`) couvrent les
/// composants isoles via `ImageRenderer`, mais pas les ecrans assembles :
/// `ImageRenderer` rend une image vide des qu'il rencontre une `NavigationSplitView`,
/// un `ScrollView`, un materiau translucide ou un pont `NSViewRepresentable` --
/// c'est-a-dire toute la coquille et tout l'editeur.
///
/// CONFIDENTIALITE : les captures sont toujours prises sur la FENETRE de Slate, jamais
/// sur l'ecran entier (`XCUIScreen.main`), qui contiendrait les autres applications de
/// l'utilisateur.
@MainActor
final class SlateLaunchUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Passe TOUJOURS par le harnais partage : il isole le store (voir
    /// `SlateUITestSupport.launchedApp`). Un `XCUIApplication()` lance directement
    /// ecrirait dans les donnees reelles de l'utilisateur.
    private func launchedApp() -> XCUIApplication {
        let app = SlateUITestSupport.launchedApp(self)
        XCTAssertEqual(app.state, .runningForeground, "L'app n'est pas passee au premier plan.")
        return app
    }

    /// Le fait qui conditionne tous les autres : l'app demarre et affiche son interface.
    ///
    /// Ce n'est pas theorique : l'app a deja refuse de demarrer (migration SwiftData
    /// cassee par un champ non optionnel), sans qu'aucun des 800 tests unitaires ne le
    /// voie -- ils utilisent tous un store neuf en memoire.
    func testAppLaunchesAndShowsItsInterface() throws {
        let app = launchedApp()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20), "Aucune fenetre n'est apparue.")

        // Si le container SwiftData echoue, l'app affiche `ContainerErrorView` au lieu
        // de l'interface : une fenetre existe quand meme, donc l'assertion ci-dessus ne
        // suffit pas a prouver que l'app va bien.
        XCTAssertFalse(
            app.staticTexts["Impossible de démarrer Slate"].exists,
            "L'app a demarre sur l'ecran d'erreur de container."
        )

        SlateUITestSupport.capture(window, named: "01-lancement", in: self)
    }

    /// La barre de menus macOS livree en phase 14, verifiee sur l'app reelle.
    func testMenuBarExposesExpectedCommands() throws {
        let app = launchedApp()
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 10))

        let titles = menuBar.menuBarItems.allElementsBoundByIndex.map { $0.title }
        for expected in ["Fichier", "Édition", "Format"] {
            XCTAssertTrue(titles.contains(expected), "Menu manquant : \(expected). Vus : \(titles)")
        }

        let fichier = menuBar.menuBarItems["Fichier"]
        fichier.click()
        let items = fichier.menuItems.allElementsBoundByIndex.map { $0.title }
        XCTAssertTrue(items.contains("Nouvelle note"), "Entree manquante. Vues : \(items)")
        XCTAssertTrue(items.contains("Nouveau dossier"), "Entree manquante. Vues : \(items)")
        // Referme le menu pour ne pas laisser l'app dans un etat modal.
        fichier.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    /// Creation d'une note par le menu, puis capture de l'interface reelle.
    func testCreatingANoteFromTheMenu() throws {
        let app = launchedApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        let menuBar = app.menuBars.firstMatch
        let fichier = menuBar.menuBarItems["Fichier"]
        fichier.click()
        fichier.menuItems["Nouvelle note"].click()

        // Laisse SwiftData inserer et l'interface se rafraichir.
        Thread.sleep(forTimeInterval: 2)
        SlateUITestSupport.capture(window, named: "02-apres-nouvelle-note", in: self)
    }
}

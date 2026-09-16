import XCTest

/// Audit de la fenetre de reglages (Phase 13, `docs/13_reglages.md`) : ouverture par
/// Cmd+,, 4 onglets, bascule de theme.
@MainActor
final class SlateSettingsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testSettingsWindowOpensWithFourTabs() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        window.typeKey(",", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1)

        // La fenetre de reglages est une fenetre macOS distincte (`Settings` scene) :
        // on cherche la fenetre dont le titre correspond, plutot que `window`
        // ci-dessus qui reste celui de la fenetre principale.
        let settingsWindow = app.windows.element(matching: NSPredicate(format: "label CONTAINS[c] %@", "Réglages"))
        let anyExtraWindow = app.windows.count > 1 ? app.windows.element(boundBy: 1) : settingsWindow
        let opened = settingsWindow.waitForExistence(timeout: 5) || anyExtraWindow.waitForExistence(timeout: 5)
        XCTAssertTrue(opened, "La fenetre de reglages ne s'est pas ouverte apres Cmd+,.")

        let targetWindow = settingsWindow.exists ? settingsWindow : anyExtraWindow
        SlateUITestSupport.capture(targetWindow, named: "80-reglages-ouverts", in: self)

        for tab in ["Apparence", "Verrouillage", "IA", "Général"] {
            XCTAssertTrue(
                app.buttons[tab].waitForExistence(timeout: 3) || app.staticTexts[tab].waitForExistence(timeout: 3),
                "Onglet de reglages introuvable : \(tab)"
            )
        }
    }

    func testAppearanceTabThemeToggle() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        window.typeKey(",", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 1)

        let appearanceTab = app.buttons["Apparence"]
        if appearanceTab.waitForExistence(timeout: 3) {
            appearanceTab.click()
            Thread.sleep(forTimeInterval: 0.5)
        }

        let settingsWindow = app.windows.count > 1 ? app.windows.element(boundBy: 1) : app.windows.firstMatch
        SlateUITestSupport.capture(settingsWindow, named: "81-reglages-apparence-avant", in: self)

        let darkButton = app.buttons["Sombre"]
        guard darkButton.waitForExistence(timeout: 5) else {
            XCTFail("Segment de theme 'Sombre' introuvable dans l'onglet Apparence.")
            return
        }
        darkButton.click()
        Thread.sleep(forTimeInterval: 1)
        SlateUITestSupport.capture(settingsWindow, named: "82-reglages-apparence-theme-sombre", in: self)
        SlateUITestSupport.capture(window, named: "83-fenetre-principale-theme-sombre", in: self)

        let lightButton = app.buttons["Clair"]
        if lightButton.waitForExistence(timeout: 3) {
            lightButton.click()
            Thread.sleep(forTimeInterval: 1)
            SlateUITestSupport.capture(window, named: "84-fenetre-principale-theme-clair", in: self)
        }

        let systemButton = app.buttons["Système"]
        if systemButton.waitForExistence(timeout: 3) {
            systemButton.click()
        }
    }
}

import XCTest

/// Audit de la coquille et de la barre laterale (Phase 3, `docs/03_sidebar_navigation.md`).
///
/// `continueAfterFailure = true` DELIBEREMENT ici (contrairement a `SlateLaunchUITests`) :
/// ce sont des tests d'AUDIT, pas des tests de non-regression. Une assertion en echec au
/// milieu d'un parcours ne doit pas empecher de capturer et d'observer les etapes
/// suivantes -- c'est la constatation elle-meme qui interesse l'audit, pas un arret net.
@MainActor
final class SlateSidebarUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    /// Etat de la sidebar au tout premier ecran : selecteur de workspace, section
    /// Espaces, pied d'actions.
    func testSidebarInitialState() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20), "Aucune fenetre n'est apparue.")

        SlateUITestSupport.capture(window, named: "10-sidebar-etat-initial", in: self)

        // Le selecteur de workspace affiche le nom du workspace courant : on verifie sa
        // presence textuelle (le constat sur un eventuel doublon nom/sous-titre se fait
        // a la lecture de la capture, un `StaticText` isole ne suffit pas a le prouver
        // par assertion).
        XCTAssertTrue(
            app.staticTexts["Espace de travail"].waitForExistence(timeout: 5),
            "Le libelle du workspace par defaut est introuvable dans la sidebar."
        )

        XCTAssertTrue(
            app.staticTexts["Espaces"].exists,
            "L'en-tete de section 'Espaces' est introuvable."
        )
    }

    /// Creation d'un dossier depuis le menu Fichier, puis selection dans l'arbre.
    func testCreateAndSelectFolder() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        let folderName = "Audit Dossier \(uniqueSuffix)"
        let created = SlateUITestSupport.createFolder(named: folderName, in: app, testCase: self)
        SlateUITestSupport.capture(window, named: "11-apres-creation-dossier", in: self)
        XCTAssertTrue(created, "La sequence de creation de dossier n'a pas pu etre menee a son terme.")
        guard created else { return }

        XCTAssertTrue(
            app.staticTexts[folderName].waitForExistence(timeout: 5),
            "Le nouveau dossier n'apparait pas dans l'arbre de la sidebar."
        )

        let selected = SlateUITestSupport.selectFolder(named: folderName, in: app)
        XCTAssertTrue(selected, "Impossible de selectionner le dossier nouvellement cree.")
        SlateUITestSupport.capture(window, named: "12-dossier-selectionne", in: self)
    }

    /// Menu contextuel d'un dossier (renommer, changer d'icone, nouveau sous-dossier,
    /// supprimer) : verifie que les entrees existent reellement.
    func testFolderContextMenu() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        let folderName = "Audit Menu \(uniqueSuffix)"
        guard SlateUITestSupport.createFolder(named: folderName, in: app, testCase: self) else {
            XCTFail("Creation de dossier prealable impossible, menu contextuel non teste.")
            return
        }

        let predicate = NSPredicate(format: "label CONTAINS[c] %@", folderName)
        let row = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Ligne du dossier introuvable pour le clic droit.")
        row.rightClick()
        SlateUITestSupport.capture(window, named: "13-menu-contextuel-dossier", in: self)

        for expected in ["Nouveau sous-dossier", "Renommer", "Changer d'icône", "Supprimer"] {
            XCTAssertTrue(
                app.menuItems[expected].waitForExistence(timeout: 3),
                "Entree de menu contextuel manquante : \(expected)"
            )
        }
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    /// Pied de sidebar : Reglages / Corbeille / Nouveau dossier / Nouvelle note, et le
    /// constat signale par Cyril -- "Nouvelle note" sans dossier selectionne.
    func testSidebarFooterAndNewNoteWithoutSelection() throws {
        let app = SlateUITestSupport.launchedApp(self)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        for label in ["Réglages", "Corbeille", "Nouveau dossier", "Nouvelle note"] {
            XCTAssertTrue(
                app.buttons[label].waitForExistence(timeout: 5),
                "Bouton de pied de sidebar manquant : \(label)"
            )
        }
        SlateUITestSupport.capture(window, named: "14-pied-de-sidebar", in: self)

        let newNoteButton = app.buttons["Nouvelle note"]
        SlateUITestSupport.capture(window, named: "15-avant-nouvelle-note-sans-dossier", in: self)
        newNoteButton.click()
        Thread.sleep(forTimeInterval: 1)
        SlateUITestSupport.capture(window, named: "16-apres-nouvelle-note-sans-dossier", in: self)
    }

    private var uniqueSuffix: String {
        String(Int(Date().timeIntervalSince1970))
    }
}

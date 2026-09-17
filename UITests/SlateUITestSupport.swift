import XCTest

/// Utilitaires partages par les tests d'interface.
enum SlateUITestSupport {
    /// Dossier ou les captures sont ecrites, en plus d'etre attachees au resultat
    /// de test.
    ///
    /// Les pieces jointes `XCTAttachment` vivent dans le bundle de resultats
    /// (`.xcresult`), qui demande `xcrun xcresulttool` pour etre ouvert. Ecrire aussi
    /// un PNG ordinaire sur disque permet de le regarder directement, ce qui est tout
    /// l'interet ici : les captures servent a etre RELUES, pas archivees.
    ///
    /// Surchargeable par la variable d'environnement `SLATE_UITEST_SCREENSHOTS` pour
    /// que l'appelant choisisse ou elles atterrissent.
    static var screenshotDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["SLATE_UITEST_SCREENSHOTS"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return URL(fileURLWithPath: "/tmp/slate_uitests", isDirectory: true)
    }

    /// Capture `element` et l'enregistre sous `named`.
    ///
    /// N'echoue jamais le test : une capture manquante est une gene, pas un defaut
    /// du produit. En cas de probleme d'ecriture, on l'annonce dans les logs de test
    /// plutot que de faire echouer une verification fonctionnelle par ailleurs saine.
    static func capture(_ element: XCUIElement, named name: String, in testCase: XCTestCase) {
        let screenshot = element.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)

        do {
            try FileManager.default.createDirectory(
                at: screenshotDirectory,
                withIntermediateDirectories: true
            )
            let url = screenshotDirectory.appendingPathComponent("\(name).png")
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            // Volontairement non bloquant, voir la documentation ci-dessus.
            print("Capture \(name) non ecrite sur disque : \(error)")
        }
    }

    /// Lance l'app et attend qu'elle passe au premier plan.
    ///
    /// Le tout premier lancement peut renvoyer 0 fenetre pendant un court instant
    /// (deja observe) : on attend `runningForeground` plutot que de conclure a un bug
    /// des la premiere verification.
    @MainActor
    static func launchedApp(_ testCase: XCTestCase) -> XCUIApplication {
        let app = XCUIApplication()
        // ISOLATION DES DONNEES, non negociable : sans ce drapeau, l'app lancee par
        // les tests ecrit dans le STORE REEL de l'utilisateur. Une premiere passe
        // d'audit a ainsi laisse 23 dossiers parasites dans la base de Cyril.
        //
        // On passe un simple drapeau et NON un chemin : l'app est sandboxee et ne peut
        // ecrire que dans son propre conteneur, donc c'est elle qui choisit ou poser le
        // store jetable (voir `SlateApp.makeContainer()`).
        app.launchEnvironment["SLATE_UITEST_ISOLATED_STORE"] = "1"
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        return app
    }

    /// Cree un dossier via le bouton "+" de la section Espaces de la sidebar, nomme
    /// `name` dans la boite de dialogue qui s'ouvre. Retourne `true` si la sequence a
    /// pu etre menee a son terme (boite de dialogue trouvee et remplie).
    ///
    /// Utilise le menu Fichier > "Nouveau dossier" plutot que le bouton du pied de
    /// sidebar : fonctionne meme si aucun dossier n'est deja selectionne (le pied de
    /// sidebar a un comportement different selon le dossier courant, voir
    /// `SidebarFooterView`).
    @MainActor
    static func createFolder(named name: String, in app: XCUIApplication, testCase: XCTestCase) -> Bool {
        let menuBar = app.menuBars.firstMatch
        guard menuBar.waitForExistence(timeout: 10) else { return false }
        let fichier = menuBar.menuBarItems["Fichier"]
        fichier.click()
        let newFolderItem = fichier.menuItems["Nouveau dossier"]
        guard newFolderItem.waitForExistence(timeout: 5) else {
            fichier.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
            return false
        }
        newFolderItem.click()

        let field = app.textFields["Nom du dossier"]
        guard field.waitForExistence(timeout: 5) else { return false }
        field.click()
        field.typeText(name)

        let confirm = app.windows.buttons["Valider"]
        guard confirm.waitForExistence(timeout: 5) else { return false }
        confirm.click()
        Thread.sleep(forTimeInterval: 1)
        return true
    }

    /// Predicat CONTAINS sur `label` OU `value` : une ligne combinee expose son texte
    /// via `value` (role `StaticText`, cote AppKit), jamais via `label` -- constate en
    /// pratique sur `FolderRow`/`NoteCell` malgre leur `.accessibilityLabel(...)`
    /// explicite. On teste les deux plutot que de figer une hypothese sur laquelle des
    /// deux proprietes AppKit choisit de peupler pour ce role.
    private static func containsPredicate(_ text: String) -> NSPredicate {
        NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", text, text)
    }

    /// Selectionne, dans la sidebar, la ligne dont le texte accessible CONTIENT `name`
    /// (le texte reel inclut aussi le compte de notes, voir `FolderRow`).
    @MainActor
    static func selectFolder(named name: String, in app: XCUIApplication) -> Bool {
        let row = app.staticTexts.matching(containsPredicate(name)).firstMatch
        guard row.waitForExistence(timeout: 5) else { return false }
        row.click()
        Thread.sleep(forTimeInterval: 0.5)
        return true
    }

    /// Bouton "Nouvelle note" du PIED DE SIDEBAR precisement (`SidebarFooterView`).
    ///
    /// `app.buttons["Nouvelle note"]` seul est AMBIGU des qu'un dossier vide est
    /// selectionne : `NoteListEmptyStateView` affiche ALORS un second bouton, "Nouvelle
    /// note" lui aussi (`noteList.empty.noNotes.newNoteButton`), et `.isEnabled`/`.click()`
    /// echouent avec "Multiple matching elements found" -- constate en pratique. On
    /// desambiguise par l'identifiant `square.and.pencil`, lui-meme partage avec le
    /// bouton "Édition" de la barre d'outils : la conjonction des deux (identifiant ET
    /// libelle) cible sans ambiguite le bouton de pied de sidebar.
    @MainActor
    static func sidebarNewNoteButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", "square.and.pencil", "Nouvelle note")
        ).firstMatch
    }

    /// Prepare un dossier neuf, cree une note dedans, la selectionne, et renvoie le
    /// premier champ de texte de blocs de son corps (le titre est un `textField`
    /// distinct, jamais confondu avec le corps). `nil` si une etape quelconque echoue --
    /// c'est alors, en soi, un constat d'audit.
    @MainActor
    static func openFreshNote(
        folderPrefix: String,
        in app: XCUIApplication,
        testCase: XCTestCase
    ) -> XCUIElement? {
        let folderName = "\(folderPrefix) \(Int(Date().timeIntervalSince1970 * 1000))"
        guard createFolder(named: folderName, in: app, testCase: testCase),
              selectFolder(named: folderName, in: app) else { return nil }

        let newNoteButton = sidebarNewNoteButton(in: app)
        guard newNoteButton.waitForExistence(timeout: 5), newNoteButton.isEnabled else { return nil }
        newNoteButton.click()
        Thread.sleep(forTimeInterval: 1)

        let body = app.textViews.firstMatch
        guard body.waitForExistence(timeout: 5) else { return nil }
        body.click()
        return body
    }

    /// Segment d'un `Picker(.segmented)` (ex. le theme Systeme/Clair/Sombre des
    /// reglages) : AppKit expose chaque segment tantot comme `.buttons`, tantot comme
    /// `.radioButtons` selon le style/la version de macOS -- on essaie les deux plutot
    /// que de figer une hypothese.
    @MainActor
    static func segment(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        let asButton = app.buttons[label]
        if asButton.exists { return asButton }
        return app.radioButtons[label]
    }

    /// Cellule de note dont le libelle accessible CONTIENT `title` (jamais une
    /// correspondance exacte : `NoteCell`/`ListCell` combinent titre + indicateurs +
    /// date relative en un seul libelle, voir leur documentation -- comme `FolderRow`
    /// pour les dossiers).
    @MainActor
    static func noteCell(titled title: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(containsPredicate(title)).firstMatch
    }
}

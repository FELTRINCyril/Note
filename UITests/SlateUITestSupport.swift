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
}

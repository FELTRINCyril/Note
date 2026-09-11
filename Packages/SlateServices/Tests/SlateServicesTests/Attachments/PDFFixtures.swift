import CoreGraphics
import Foundation

/// Fabrique un PDF minimal en memoire pour les tests d'extraction du nombre de pages,
/// afin de ne pas embarquer de fichier binaire dans le depot.
enum PDFFixtures {
    static func twoPagePDFData() -> Data {
        let mutableData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 200, height: 200)
        guard let consumer = CGDataConsumer(data: mutableData),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            preconditionFailure("Impossible de creer le contexte PDF de test.")
        }
        for _ in 0..<2 {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(mediaBox)
            context.endPDFPage()
        }
        context.closePDF()
        return mutableData as Data
    }
}

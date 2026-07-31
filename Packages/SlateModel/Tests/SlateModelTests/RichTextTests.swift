import Foundation
import Testing

@testable import SlateModel

@Suite("RichText")
struct RichTextTests {

    // MARK: - Critere d'acceptation Phase 2 :
    // "Un bloc texte avec gras + lien + surlignage se serialise et se relit a l'identique."
    //
    // On verifie explicitement que chaque attribut est toujours present sur la bonne plage
    // apres decodage, pas seulement que le texte brut est identique (un test sur le seul
    // texte brut serait vide de sens : il passerait meme si le round-trip perdait tous les
    // attributs custom, exactement le piege documente dans RichText.swift).
    @Test("gras + lien + surlignage sur des plages differentes et partiellement chevauchantes")
    func boldLinkHighlightRoundTrip() throws {
        // "Bonjour le monde ici" (21 caracteres)
        //  0123456789012345678901
        // gras       : [8..14)  -> "le mon"
        // lien       : [11..17) -> "monde " (chevauche le gras sur [11..14))
        // surlignage : [0..7)   -> "Bonjour" (plage disjointe des deux autres)
        var text = RichText(plainText: "Bonjour le monde ici")
        let boldRange = text.range(charactersOffset: 8..<14)
        let linkRange = text.range(charactersOffset: 11..<17)
        let highlightRange = text.range(charactersOffset: 0..<7)
        let url = URL(string: "https://kreaddis.com")!
        let color = SlateHighlightColor("#FFEE88")

        text.apply(.bold, to: boldRange)
        text.apply(.link(url), to: linkRange)
        text.apply(.highlight(color), to: highlightRange)

        let encoded = try JSONEncoder().encode(text)
        let decoded = try JSONDecoder().decode(RichText.self, from: encoded)

        #expect(decoded.plainText == "Bonjour le monde ici")

        let decodedBoldRange = decoded.range(charactersOffset: 8..<14)
        let decodedLinkRange = decoded.range(charactersOffset: 11..<17)
        let decodedHighlightRange = decoded.range(charactersOffset: 0..<7)

        #expect(decoded.attributedString[decodedBoldRange].inlinePresentationIntent == .stronglyEmphasized)
        #expect(decoded.attributedString[decodedLinkRange].link == url)
        #expect(decoded.attributedString[decodedHighlightRange].slateHighlight == color)

        // Les attributs ne doivent pas avoir "deborde" hors de leur plage d'origine.
        let beforeBold = decoded.range(charactersOffset: 0..<8)
        #expect(decoded.attributedString[beforeBold].inlinePresentationIntent == nil)

        let afterHighlight = decoded.range(charactersOffset: 7..<8)
        #expect(decoded.attributedString[afterHighlight].slateHighlight == nil)

        // La zone de chevauchement gras/lien doit porter les deux attributs a la fois.
        let overlap = decoded.range(charactersOffset: 11..<14)
        #expect(decoded.attributedString[overlap].inlinePresentationIntent == .stronglyEmphasized)
        #expect(decoded.attributedString[overlap].link == url)

        // La partie du lien hors chevauchement ne doit pas etre en gras.
        let linkOnly = decoded.range(charactersOffset: 14..<17)
        #expect(decoded.attributedString[linkOnly].link == url)
        #expect(decoded.attributedString[linkOnly].inlinePresentationIntent == nil)

        #expect(decoded == text)
    }

    @Test("italique + souligne + barre + code inline")
    func italicUnderlineStrikethroughInlineCodeRoundTrip() throws {
        // "swift six concurrency" (21 caracteres)
        //  012345678901234567890
        var text = RichText(plainText: "swift six concurrency")
        let italicRange = text.range(charactersOffset: 0..<5)
        let underlineRange = text.range(charactersOffset: 6..<9)
        let strikethroughRange = text.range(charactersOffset: 10..<21)
        let codeRange = text.range(charactersOffset: 0..<5)

        text.apply(.italic, to: italicRange)
        text.apply(.underline, to: underlineRange)
        text.apply(.strikethrough, to: strikethroughRange)
        text.apply(.inlineCode, to: codeRange)

        let encoded = try JSONEncoder().encode(text)
        let decoded = try JSONDecoder().decode(RichText.self, from: encoded)

        let decodedItalicRange = decoded.range(charactersOffset: 0..<5)
        let decodedUnderlineRange = decoded.range(charactersOffset: 6..<9)
        let decodedStrikethroughRange = decoded.range(charactersOffset: 10..<21)

        #expect(decoded.attributedString[decodedItalicRange].inlinePresentationIntent == .emphasized)
        #expect(decoded.attributedString[decodedItalicRange].slateInlineCode == true)
        #expect(decoded.attributedString[decodedUnderlineRange].slateUnderline == true)
        #expect(decoded.attributedString[decodedStrikethroughRange].inlinePresentationIntent == .strikethrough)

        // La zone non taguee ne doit porter aucun de ces attributs.
        let untouched = decoded.range(charactersOffset: 5..<6)
        #expect(decoded.attributedString[untouched].inlinePresentationIntent == nil)
        #expect(decoded.attributedString[untouched].slateUnderline == nil)
        #expect(decoded.attributedString[untouched].slateInlineCode == nil)

        #expect(decoded == text)
    }

    @Test("remove retire une marque sans toucher aux autres")
    func removeMarkKeepsOthers() {
        var text = RichText(plainText: "abcdef")
        let range = text.range(charactersOffset: 0..<6)

        text.apply(.bold, to: range)
        text.apply(.italic, to: range)
        text.apply(.highlight(SlateHighlightColor("yellow")), to: range)

        text.remove(.bold, from: range)

        #expect(text.attributedString[range].inlinePresentationIntent == .emphasized)
        #expect(text.attributedString[range].slateHighlight == SlateHighlightColor("yellow"))
    }

    @Test("plainText avec accents et emoji")
    func plainTextWithAccentsAndEmoji() {
        let text = RichText(plainText: "Café à la crème 🎉 déjà vu")
        #expect(text.plainText == "Café à la crème 🎉 déjà vu")
    }

    @Test("RichText vide round-trip sans erreur")
    func emptyRoundTrip() throws {
        let empty = RichText()
        #expect(empty.isEmpty)
        #expect(empty.plainText.isEmpty)

        let encoded = try JSONEncoder().encode(empty)
        let decoded = try JSONDecoder().decode(RichText.self, from: encoded)

        #expect(decoded.isEmpty)
        #expect(decoded == empty)
    }

    @Test("egalite et hachage coherents")
    func equalityAndHashing() {
        var textA = RichText(plainText: "identique")
        var textB = RichText(plainText: "identique")
        let rangeA = textA.range(charactersOffset: 0..<4)
        let rangeB = textB.range(charactersOffset: 0..<4)

        textA.apply(.bold, to: rangeA)
        textB.apply(.bold, to: rangeB)

        #expect(textA == textB)
        #expect(textA.hashValue == textB.hashValue)

        textB.apply(.italic, to: rangeB)
        #expect(textA != textB)
    }

    @Test("initialiseur depuis AttributedString brut")
    func initFromAttributedString() {
        let attributed = AttributedString("brut")
        let text = RichText(attributedString: attributed)
        #expect(text.plainText == "brut")
    }
}

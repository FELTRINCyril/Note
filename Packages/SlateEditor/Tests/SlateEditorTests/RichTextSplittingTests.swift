import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `RichText.split(atCharacterOffset:)` : preservation des attributs de chaque moitie
/// (docs/05_editeur_blocs.md, sous-etape 5.3 -- "le split doit preserver les ATTRIBUTS
/// inline de chaque moitie").
@Suite("RichText.split(atCharacterOffset:)")
struct RichTextSplittingTests {
    @Test("Le texte est coupe exactement a l'offset donne")
    func splitsTextAtOffset() {
        let text = RichText(plainText: "Bonjour le monde")

        let (head, tail) = text.split(atCharacterOffset: 7)

        #expect(head.plainText == "Bonjour")
        #expect(tail.plainText == " le monde")
    }

    @Test("Un attribut applique sur la premiere moitie est preserve apres split")
    func preservesAttributesOnHead() {
        var text = RichText(plainText: "Bonjour le monde")
        text.apply(.bold, to: text.range(charactersOffset: 0..<7))

        let (head, tail) = text.split(atCharacterOffset: 7)

        #expect(head.attributedString.runs.first?.inlinePresentationIntent == .stronglyEmphasized)
        #expect(tail.attributedString.runs.first?.inlinePresentationIntent == nil)
    }

    @Test("Un attribut applique sur la seconde moitie est preserve apres split")
    func preservesAttributesOnTail() {
        var text = RichText(plainText: "Bonjour le monde")
        text.apply(.italic, to: text.range(charactersOffset: 8..<10))

        let (_, tail) = text.split(atCharacterOffset: 7)

        // Dans `tail`, l'italique commence desormais a l'offset 1 (" le monde" moins
        // le premier caractere d'espace) -- verifie via `plainText` + le run associe.
        #expect(tail.plainText == " le monde")
        let italicRun = tail.attributedString.runs.first { $0.inlinePresentationIntent == .emphasized }
        #expect(italicRun != nil)
    }

    @Test("Un attribut a cheval sur la frontiere se retrouve des deux cotes")
    func attributeSpanningBoundaryEndsUpOnBothSides() {
        var text = RichText(plainText: "Bonjour le monde")
        text.apply(.bold, to: text.range(charactersOffset: 4..<10))

        let (head, tail) = text.split(atCharacterOffset: 7)

        let headBold = head.attributedString.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized }
        let tailBold = tail.attributedString.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(headBold)
        #expect(tailBold)
    }

    @Test("Split a l'offset 0 : head vide, tail = texte entier")
    func splitAtStartYieldsEmptyHead() {
        let text = RichText(plainText: "Bonjour")

        let (head, tail) = text.split(atCharacterOffset: 0)

        #expect(head.isEmpty)
        #expect(tail.plainText == "Bonjour")
    }

    @Test("Split a la longueur exacte : head = texte entier, tail vide")
    func splitAtEndYieldsEmptyTail() {
        let text = RichText(plainText: "Bonjour")

        let (head, tail) = text.split(atCharacterOffset: 7)

        #expect(head.plainText == "Bonjour")
        #expect(tail.isEmpty)
    }

    @Test("Un offset hors bornes est borne, jamais un crash")
    func clampsOutOfBoundsOffset() {
        let text = RichText(plainText: "Bonjour")

        let (headNegative, tailNegative) = text.split(atCharacterOffset: -5)
        let (headOverflow, tailOverflow) = text.split(atCharacterOffset: 500)

        #expect(headNegative.isEmpty)
        #expect(tailNegative.plainText == "Bonjour")
        #expect(headOverflow.plainText == "Bonjour")
        #expect(tailOverflow.isEmpty)
    }
}

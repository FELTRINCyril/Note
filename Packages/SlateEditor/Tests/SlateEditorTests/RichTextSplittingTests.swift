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

/// `RichText.removingCharacters(in:)` (Phase 6, sous-etape 6.6) : bornes, preservation
/// des attributs de part et d'autre de la plage retiree, graphemes composes -- voir la
/// documentation de tete de `RichTextSplitting.swift`. Suite separee de
/// `RichTextSplittingTests` (type different, meme fichier source) plutot qu'ajoutee au
/// `@Suite` ci-dessus, pour que le nom du test reflette la fonction testee.
@Suite("RichText.removingCharacters(in:)")
struct RichTextRemovingCharactersTests {
    /// Construit une `RichTextRange` a partir d'offsets de caracteres bruts -- helper
    /// local, `RichText.range(charactersOffset:)` (utilise par les tests de `split`
    /// ci-dessus) renvoie un `Range<AttributedString.Index>` de `SlateModel`, un type
    /// DIFFERENT de `RichTextRange` (propre a `SlateEditor`, consomme par
    /// `removingCharacters(in:)`) -- jamais interchangeables.
    private func range(_ offsets: Range<Int>) -> RichTextRange {
        RichTextRange(
            lowerBound: RichTextOffset(characters: offsets.lowerBound),
            upperBound: RichTextOffset(characters: offsets.upperBound)
        )
    }

    @Test("Retire exactement les caracteres de la plage, garde le reste")
    func removesExactRange() {
        let text = RichText(plainText: "Bonjour le monde")

        let result = text.removingCharacters(in: range(7..<10))

        #expect(result.plainText == "Bonjour monde")
    }

    @Test("Plage vide (lowerBound == upperBound) : aucun caractere retire")
    func emptyRangeRemovesNothing() {
        let text = RichText(plainText: "Bonjour")

        let result = text.removingCharacters(in: range(3..<3))

        #expect(result.plainText == "Bonjour")
    }

    @Test("Plage couvrant la fin exacte du texte : tout ce qui suit lowerBound disparait")
    func rangeAtEndRemovesTrailingText() {
        let text = RichText(plainText: "Bonjour le monde")

        let result = text.removingCharacters(in: range(7..<17))

        #expect(result.plainText == "Bonjour")
    }

    @Test("Plage couvrant le texte entier : resultat vide")
    func rangeCoveringWholeTextYieldsEmpty() {
        let text = RichText(plainText: "Bonjour")

        let result = text.removingCharacters(in: range(0..<7))

        #expect(result.isEmpty)
    }

    @Test("Bornes hors du texte (au-dela de la longueur) : bornees, jamais un crash")
    func outOfBoundsUpperBoundIsClamped() {
        let text = RichText(plainText: "Bonjour")

        let result = text.removingCharacters(
            in: RichTextRange(lowerBound: RichTextOffset(characters: 3), upperBound: RichTextOffset(characters: 500))
        )

        #expect(result.plainText == "Bon")
    }

    @Test("Borne inferieure hors du texte (au-dela de la longueur) : resultat inchange")
    func outOfBoundsLowerBoundIsClamped() {
        let text = RichText(plainText: "Bonjour")

        let result = text.removingCharacters(
            in: RichTextRange(lowerBound: RichTextOffset(characters: 500), upperBound: RichTextOffset(characters: 500))
        )

        #expect(result.plainText == "Bonjour")
    }

    @Test("Attributs preserves de PART ET D'AUTRE de la plage retiree, jamais fusionnes")
    func preservesAttributesOnBothSidesOfRemovedRange() {
        var text = RichText(plainText: "Bonjour le monde")
        text.apply(.bold, to: text.range(charactersOffset: 0..<7))
        text.apply(.italic, to: text.range(charactersOffset: 11..<16))

        let result = text.removingCharacters(in: range(7..<10))

        #expect(result.plainText == "Bonjour monde")
        let boldRun = result.attributedString.runs.first { $0.inlinePresentationIntent == .stronglyEmphasized }
        let italicRun = result.attributedString.runs.first { $0.inlinePresentationIntent == .emphasized }
        #expect(boldRun != nil)
        #expect(italicRun != nil)
    }

    @Test("Graphemes composes (emoji drapeau) : le retrait ne coupe jamais un grapheme en deux")
    func doesNotSplitComposedGraphemeClusters() {
        // "Bonjour 🇫🇷 monde" -- le drapeau est un SEUL `Character` (grapheme compose de
        // deux scalaires Unicode), exactement le cas qui a deja fait deraper une
        // conversion UTF-16/caracteres ailleurs dans ce projet (voir la documentation de
        // tete de `RichTextSplitting.swift`/`RichTextOffset`).
        let text = RichText(plainText: "Bonjour 🇫🇷 monde")
        let flagOffset = 8
        #expect(Array(text.plainText)[flagOffset] == "🇫🇷")

        let result = text.removingCharacters(
            in: RichTextRange(
                lowerBound: RichTextOffset(characters: flagOffset),
                upperBound: RichTextOffset(characters: flagOffset + 1)
            )
        )

        #expect(result.plainText == "Bonjour  monde")
    }
}

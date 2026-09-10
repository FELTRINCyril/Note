import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// Formatage inline (docs/07_typographie_formatage.md) : application/retrait de chaque
/// marque, cumul sur une meme plage, comportement bascule, detection de l'etat actif
/// (dont le cas PARTIEL), persistance a travers `Block.text`, et conversion de bloc via
/// les memes methodes que les raccourcis Cmd+Opt+0..3.
///
/// Meme regle que `EditorControllerTests` : aucun `NSTextView` ni `ModelContext`, une
/// `Note`/`Block` en memoire et l'observation directe des methodes publiques
/// d'`EditorController+Formatting.swift`.
@MainActor
@Suite("EditorController.Formatting")
struct EditorControllerFormattingTests {
    /// Regroupe les trois valeurs necessaires a chaque test (au lieu d'un tuple a 3
    /// membres, au-dela du seuil `large_tuple` de SwiftLint).
    private struct Fixture {
        let note: Note
        let block: Block
        let controller: EditorController
    }

    private func makeBlock(_ text: String) -> Fixture {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: text), note: note)
        note.blocks = [block]
        return Fixture(note: note, block: block, controller: EditorController(note: note))
    }

    private func fullRange(of text: String) -> RichTextRange {
        range(0, text.count)
    }

    /// Raccourci pour une plage exprimee en offsets de CARACTERES bruts (`Int`) --
    /// evite de repeter `RichTextOffset(characters:)` deux fois a chaque site d'appel.
    private func range(_ lower: Int, _ upper: Int) -> RichTextRange {
        RichTextRange(lowerBound: RichTextOffset(characters: lower), upperBound: RichTextOffset(characters: upper))
    }

    // MARK: - Marques booleennes : application, retrait, bascule

    @Test("toggleMark applique une marque absente")
    func toggleMarkApplies() {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller
        let range = fullRange(of: "Bonjour")

        controller.toggleMark(.bold, in: block, range: range)

        #expect(controller.isMarkActive(.bold, in: block, range: range))
    }

    @Test("toggleMark retire une marque presente PARTOUT sur la plage (bascule)")
    func toggleMarkRemovesWhenFullyActive() {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller
        let range = fullRange(of: "Bonjour")
        controller.toggleMark(.italic, in: block, range: range)
        #expect(controller.isMarkActive(.italic, in: block, range: range))

        controller.toggleMark(.italic, in: block, range: range)

        #expect(controller.isMarkActive(.italic, in: block, range: range) == false)
    }

    @Test("isMarkActive est faux si la marque n'est presente que PARTIELLEMENT sur la plage")
    func isMarkActiveFalseOnPartialCoverage() {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller
        // Applique le gras sur seulement la premiere moitie.
        let partial = range(0, 3)
        controller.toggleMark(.bold, in: block, range: partial)

        #expect(controller.isMarkActive(.bold, in: block, range: fullRange(of: "Bonjour")) == false)
        #expect(controller.isMarkActive(.bold, in: block, range: partial))
    }

    @Test("toggleMark sans selection (plage vide) est sans effet")
    func toggleMarkIgnoresEmptyRange() {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller
        let caret = RichTextRange(caret: RichTextOffset(characters: 2))

        let handled = controller.toggleMark(.bold, in: block, range: caret)

        #expect(handled == false)
        #expect(controller.isMarkActive(.bold, in: block, range: fullRange(of: "Bonjour")) == false)
    }

    @Test("Cumul : gras + surlignage + couleur de texte peuvent coexister sur la meme plage")
    func marksAccumulateOnSameRange() {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller
        let range = fullRange(of: "Bonjour")

        controller.toggleMark(.bold, in: block, range: range)
        controller.setHighlight(SlateHighlightColor("yellow"), in: block, range: range)
        controller.setTextColor(SlateTextColor("blue"), in: block, range: range)

        #expect(controller.isMarkActive(.bold, in: block, range: range))
        #expect(controller.activeHighlight(in: block, range: range)?.value == "yellow")
        #expect(controller.activeTextColor(in: block, range: range)?.value == "blue")
    }

    @Test("Retrait selectif : retirer le gras d'une plage NE touche pas une marque voisine")
    func removingMarkDoesNotAffectNeighbor() {
        let fixture = makeBlock("Bonjour tout le monde")
        let block = fixture.block
        let controller = fixture.controller
        let firstWord = range(0, 7)
        let secondWord = range(8, 12)
        controller.toggleMark(.bold, in: block, range: firstWord)
        controller.toggleMark(.bold, in: block, range: secondWord)

        controller.toggleMark(.bold, in: block, range: firstWord)

        #expect(controller.isMarkActive(.bold, in: block, range: firstWord) == false)
        #expect(controller.isMarkActive(.bold, in: block, range: secondWord))
    }

    // MARK: - Surlignage / couleur de texte : bascule et retrait cible

    @Test("setHighlight(nil) retire le surlignage deja applique")
    func setHighlightNilRemoves() {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller
        let range = fullRange(of: "Bonjour")
        controller.setHighlight(SlateHighlightColor("green"), in: block, range: range)

        controller.setHighlight(nil, in: block, range: range)

        #expect(controller.activeHighlight(in: block, range: range) == nil)
    }

    @Test("activeHighlight est nil si la plage porte des surlignages MELANGES")
    func activeHighlightNilWhenMixed() {
        let fixture = makeBlock("Bonjour tout le monde")
        let block = fixture.block
        let controller = fixture.controller
        let firstWord = range(0, 7)
        let secondWord = range(8, 12)
        controller.setHighlight(SlateHighlightColor("yellow"), in: block, range: firstWord)
        controller.setHighlight(SlateHighlightColor("blue"), in: block, range: secondWord)

        let combined = RichTextRange(lowerBound: firstWord.lowerBound, upperBound: secondWord.upperBound)
        #expect(controller.activeHighlight(in: block, range: combined) == nil)
    }

    // MARK: - Lien

    @Test("setLink applique puis retire un lien, ferme la demande d'edition en attente")
    func setLinkAppliesAndRemoves() throws {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller
        let range = fullRange(of: "Bonjour")
        let url = try #require(URL(string: "https://exemple.fr"))
        controller.requestLinkEditor(in: block, range: range)
        #expect(controller.linkEditRequest != nil)

        controller.setLink(url, in: block, range: range)

        #expect(controller.currentLink(in: block, range: range) == url)
        #expect(controller.linkEditRequest == nil)

        controller.setLink(nil, in: block, range: range)

        #expect(controller.currentLink(in: block, range: range) == nil)
    }

    @Test("currentLink est nil sur une plage qui couvre deux liens differents")
    func currentLinkNilWhenMultipleLinks() throws {
        let fixture = makeBlock("Bonjour tout le monde")
        let block = fixture.block
        let controller = fixture.controller
        let firstWord = range(0, 7)
        let secondWord = range(8, 12)
        let urlA = try #require(URL(string: "https://a.fr"))
        let urlB = try #require(URL(string: "https://b.fr"))
        controller.setLink(urlA, in: block, range: firstWord)
        controller.setLink(urlB, in: block, range: secondWord)

        let combined = RichTextRange(lowerBound: firstWord.lowerBound, upperBound: secondWord.upperBound)
        #expect(controller.currentLink(in: block, range: combined) == nil)
    }

    // MARK: - Retirer tout le formatage

    @Test("removeAllFormatting retire les 8 marques d'un coup")
    func removeAllFormattingClearsEverything() throws {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller
        let range = fullRange(of: "Bonjour")
        let url = try #require(URL(string: "https://exemple.fr"))
        for kind in FormattingMarkKind.allCases {
            controller.toggleMark(kind, in: block, range: range)
        }
        controller.setHighlight(SlateHighlightColor("yellow"), in: block, range: range)
        controller.setTextColor(SlateTextColor("blue"), in: block, range: range)
        controller.setLink(url, in: block, range: range)

        controller.removeAllFormatting(in: block, range: range)

        for kind in FormattingMarkKind.allCases {
            #expect(controller.isMarkActive(kind, in: block, range: range) == false)
        }
        #expect(controller.activeHighlight(in: block, range: range) == nil)
        #expect(controller.activeTextColor(in: block, range: range) == nil)
        #expect(controller.currentLink(in: block, range: range) == nil)
    }

    // MARK: - Persistance : une marque survit a un aller-retour par Block.text

    @Test("Une marque appliquee survit a un encodage/decodage de Block.text (BlockTextCommit)")
    func markSurvivesRoundTripThroughBlockText() throws {
        let fixture = makeBlock("Bonjour")
        let note = fixture.note
        let block = fixture.block
        let controller = fixture.controller
        let range = fullRange(of: "Bonjour")
        controller.toggleMark(.bold, in: block, range: range)
        controller.setHighlight(SlateHighlightColor("yellow"), in: block, range: range)

        // Aller-retour Codable, exactement le chemin emprunte par la persistance
        // SwiftData (voir la documentation de `RichText`, "le piege du round-trip
        // Codable") -- sans configuration explicite du scope, ce test echouerait.
        let originalText = try #require(block.text)
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalText)
        let decoded = try JSONDecoder().decode(RichText.self, from: data)
        block.text = decoded

        #expect(controller.isMarkActive(.bold, in: block, range: range))
        #expect(controller.activeHighlight(in: block, range: range)?.value == "yellow")
        #expect(note.plainText == "Bonjour")
    }

    // MARK: - Selection inline (barre flottante)

    @Test("updateInlineSelection ignore une plage vide (caret ponctuel)")
    func updateInlineSelectionIgnoresEmptyRange() {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller

        controller.updateInlineSelection(for: block, range: RichTextRange(caret: 2), rect: .zero)

        #expect(controller.inlineSelection == nil)
    }

    @Test("updateInlineSelection expose la selection, clearInlineSelection l'efface")
    func updateAndClearInlineSelection() {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller
        let range = fullRange(of: "Bonjour")

        controller.updateInlineSelection(for: block, range: range, rect: CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(controller.inlineSelection?.blockID == block.id)

        controller.clearInlineSelection(for: block.id)

        #expect(controller.inlineSelection == nil)
    }

    // MARK: - Conversion de bloc (memes methodes que Cmd+Opt+0..3)

    @Test("convertBlock vers un titre puis retour au paragraphe (Cmd+Opt+1 / Cmd+Opt+0)")
    func convertBlockToHeadingAndBackToParagraph() {
        let fixture = makeBlock("Bonjour")
        let block = fixture.block
        let controller = fixture.controller

        controller.convertBlock(block, to: .heading1)
        #expect(block.type == .heading1)

        controller.convertBlock(block, to: .paragraph)
        #expect(block.type == .paragraph)
    }
}

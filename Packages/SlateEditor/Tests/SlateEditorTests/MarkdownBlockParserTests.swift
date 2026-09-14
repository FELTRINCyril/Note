import SlateModel
import Testing

@testable import SlateEditor

/// `MarkdownBlockParser` (docs/15_markdown_natif.md, "Coller du markdown -> conversion
/// optionnelle en blocs") : un test par motif au collage, le cas multi-lignes avec bloc
/// de code, et le texte sans markdown qui doit rester du texte.
@Suite("MarkdownBlockParser")
struct MarkdownBlockParserTests {
    // MARK: - Un bloc par motif

    @Test("Titre : une ligne \"# ...\" devient un bloc H1")
    func headingLineBecomesHeadingBlock() {
        let blocks = MarkdownBlockParser.parse("# Titre")

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .heading1)
        #expect(blocks[0].text.plainText == "Titre")
    }

    @Test("Puce : une ligne \"- ...\" devient un bloc de liste a puces")
    func bulletLineBecomesBulletedListBlock() {
        let blocks = MarkdownBlockParser.parse("- Lait")

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .bulletedList)
        #expect(blocks[0].text.plainText == "Lait")
    }

    @Test("Liste numerotee : une ligne \"1. ...\" devient un bloc de liste numerotee")
    func numberedLineBecomesNumberedListBlock() {
        let blocks = MarkdownBlockParser.parse("1. Premier")

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .numberedList)
        #expect(blocks[0].text.plainText == "Premier")
    }

    @Test("Tache cochee : une ligne \"[x] ...\" devient un bloc tache COCHEE")
    func checkedTodoLineBecomesCheckedTodoBlock() {
        let blocks = MarkdownBlockParser.parse("[x] Fait")

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .todo)
        #expect(blocks[0].isChecked)
        #expect(blocks[0].text.plainText == "Fait")
    }

    @Test("Tache non cochee : une ligne \"[] ...\" devient un bloc tache NON cochee")
    func uncheckedTodoLineBecomesUncheckedTodoBlock() {
        let blocks = MarkdownBlockParser.parse("[] A faire")

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .todo)
        #expect(blocks[0].isChecked == false)
    }

    @Test("Citation : une ligne \"> ...\" devient un bloc citation")
    func quoteLineBecomesQuoteBlock() {
        let blocks = MarkdownBlockParser.parse("> Une citation")

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .quote)
        #expect(blocks[0].text.plainText == "Une citation")
    }

    @Test("Separateur : une ligne \"---\" seule devient un bloc separateur")
    func dividerLineBecomesDividerBlock() {
        let blocks = MarkdownBlockParser.parse("---")

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .divider)
        #expect(blocks[0].text.isEmpty)
    }

    @Test("Formatage inline : les 5 marques sont appliquees et les delimiteurs retires")
    func inlineMarksAreAppliedAndConsumed() throws {
        let blocks = MarkdownBlockParser.parse("**gras** *italique* `code` ~~barre~~ ==surlignage==")

        #expect(blocks.count == 1)
        #expect(blocks[0].text.plainText == "gras italique code barre surlignage")
        let text = blocks[0].text
        #expect(FormattingEngine.isMarkActive(.bold, in: text, range: text.range(charactersOffset: 0..<4)))
        #expect(FormattingEngine.isMarkActive(.italic, in: text, range: text.range(charactersOffset: 5..<13)))
        #expect(FormattingEngine.isMarkActive(.inlineCode, in: text, range: text.range(charactersOffset: 14..<18)))
        #expect(FormattingEngine.isMarkActive(.strikethrough, in: text, range: text.range(charactersOffset: 19..<24)))
    }

    // MARK: - Multi-lignes : plusieurs blocs, ligne vide = separateur SANS bloc

    @Test("Plusieurs lignes non vides deviennent chacune leur PROPRE bloc")
    func multipleNonBlankLinesEachBecomeTheirOwnBlock() {
        let blocks = MarkdownBlockParser.parse("# Titre\n- Un\n- Deux")

        #expect(blocks.count == 3)
        #expect(blocks[0].type == .heading1)
        #expect(blocks[1].type == .bulletedList)
        #expect(blocks[1].text.plainText == "Un")
        #expect(blocks[2].text.plainText == "Deux")
    }

    @Test("Une ligne vide separe deux groupes sans produire de bloc elle-meme")
    func blankLineSeparatesWithoutProducingABlock() {
        let blocks = MarkdownBlockParser.parse("Un paragraphe\n\nUn autre paragraphe")

        #expect(blocks.count == 2)
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[1].type == .paragraph)
    }

    // MARK: - Bloc de code : le seul motif reellement multi-lignes

    @Test("Un bloc delimite par ``` sur plusieurs lignes devient UN SEUL bloc de code")
    func fencedCodeBlockSpanningMultipleLinesBecomesOneCodeBlock() {
        let blocks = MarkdownBlockParser.parse("```\nlet x = 1\nlet y = 2\n```")

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .code)
        #expect(blocks[0].text.plainText == "let x = 1\nlet y = 2")
    }

    @Test("Le contenu d'un bloc de code n'est JAMAIS interprete comme du markdown")
    func codeBlockContentIsNeverInterpretedAsMarkdown() {
        let blocks = MarkdownBlockParser.parse("```\n# pas un titre\n**pas du gras**\n```")

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .code)
        #expect(blocks[0].text.plainText == "# pas un titre\n**pas du gras**")
    }

    @Test("Texte avant et apres un bloc de code produit des blocs distincts, dans l'ordre")
    func textSurroundingAFencedCodeBlockProducesSeparateBlocksInOrder() {
        let blocks = MarkdownBlockParser.parse("# Avant\n```\ncode\n```\nApres")

        #expect(blocks.count == 3)
        #expect(blocks[0].type == .heading1)
        #expect(blocks[1].type == .code)
        #expect(blocks[2].type == .paragraph)
        #expect(blocks[2].text.plainText == "Apres")
    }

    // MARK: - Texte sans markdown : reste du texte

    @Test("Un texte sans aucun motif markdown reste un simple paragraphe, inchange")
    func plainTextStaysPlainParagraph() {
        let blocks = MarkdownBlockParser.parse("Un texte tout a fait ordinaire.")

        #expect(blocks.count == 1)
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[0].text.plainText == "Un texte tout a fait ordinaire.")
    }

    @Test("containsMarkdownSyntax est faux pour un texte sans motif")
    func containsMarkdownSyntaxFalseForPlainText() {
        #expect(MarkdownBlockParser.containsMarkdownSyntax("Un texte tout a fait ordinaire.") == false)
        #expect(MarkdownBlockParser.containsMarkdownSyntax("et / ou, 23 - 45") == false)
    }

    @Test("containsMarkdownSyntax est vrai des qu'un motif de bloc OU inline est present")
    func containsMarkdownSyntaxTrueAsSoonAsAnyMotifIsPresent() {
        #expect(MarkdownBlockParser.containsMarkdownSyntax("# Titre"))
        #expect(MarkdownBlockParser.containsMarkdownSyntax("du texte avec **du gras** dedans"))
        #expect(MarkdownBlockParser.containsMarkdownSyntax("---"))
    }
}

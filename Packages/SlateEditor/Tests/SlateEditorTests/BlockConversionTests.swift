import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `BlockConversion` : logique PURE (aucun AppKit, aucun `ModelContext`) de la
/// conversion de type de bloc (docs/05_editeur_blocs.md, sous-etape 5.5). Ces tests
/// construisent des `Note`/`Block` en memoire, exactement comme `BlockOperationsTests`.
@MainActor
@Suite("BlockConversion")
struct BlockConversionTests {
    // MARK: - Texte riche preserve (paragraphe <-> titres)

    @Test("convert(_:to:) vers chaque niveau de titre preserve le texte ET les attributs inline")
    func convertToEachHeadingLevelPreservesRichText() {
        for level in 1...6 {
            let type = headingType(forLevel: level)
            let note = Note(title: "Test")
            var text = RichText(plainText: "Bonjour le monde")
            text.apply(.bold, to: text.range(charactersOffset: 0..<7)) // "Bonjour"
            text.apply(.link(URL(string: "https://example.com")!), to: text.range(charactersOffset: 8..<10)) // "le"
            text.apply(.highlight(SlateHighlightColor("yellow")), to: text.range(charactersOffset: 11..<16)) // "monde"
            let block = Block(order: 0, type: .paragraph, text: text, note: note)
            note.blocks = [block]

            BlockConversion.convert(block, to: type)

            // `Block.text` est une propriete CALCULEE (encode/decode JSON a chaque
            // acces, voir `Block.swift`) : deux acces successifs retournent des
            // `AttributedString` distincts en memoire. Les `AttributedString.Index`
            // calcules sur `text` (avant conversion) ne sont donc PAS valables sur
            // `block.text` (apres) -- il faut relire `block.text` UNE fois et calculer
            // les plages depuis CETTE instance.
            let converted = block.text ?? RichText()
            let boldRange = converted.range(charactersOffset: 0..<7)
            let linkRange = converted.range(charactersOffset: 8..<10)
            let highlightRange = converted.range(charactersOffset: 11..<16)
            let boldIntent = converted.attributedString[boldRange].inlinePresentationIntent
            let linkURL = converted.attributedString[linkRange].link
            let highlight = converted.attributedString[highlightRange].slateHighlight
            #expect(block.type == type)
            #expect(converted.plainText == "Bonjour le monde")
            #expect(boldIntent == .stronglyEmphasized)
            #expect(linkURL == URL(string: "https://example.com"))
            #expect(highlight == SlateHighlightColor("yellow"))
        }
    }

    @Test("convert(_:to:) d'un titre vers un paragraphe puis retour vers un titre preserve toujours le texte")
    func convertHeadingBackAndForthPreservesText() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .heading2, text: RichText(plainText: "Un titre"), note: note)
        note.blocks = [block]

        BlockConversion.convert(block, to: .paragraph)
        #expect(block.type == .paragraph)
        #expect(block.text?.plainText == "Un titre")

        BlockConversion.convert(block, to: .heading3)
        #expect(block.type == .heading3)
        #expect(block.text?.plainText == "Un titre")
    }

    // MARK: - Attributs : `headingLevel` recalcule, jamais transporte

    @Test("convert(_:to:) vers un titre recalcule headingLevel a la valeur du type d'arrivee")
    func convertToHeadingRecomputesHeadingLevel() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Texte"), note: note)
        note.blocks = [block]

        BlockConversion.convert(block, to: .heading4)

        #expect(block.attributes.headingLevel == 4)
    }

    @Test("convert(_:to:) hors d'un titre remet headingLevel a nil")
    func convertOutOfHeadingClearsHeadingLevel() {
        let note = Note(title: "Test")
        var attributes = BlockAttributes()
        attributes.headingLevel = 2
        let block = Block(
            order: 0, type: .heading2, text: RichText(plainText: "Texte"), attributes: attributes, note: note
        )
        note.blocks = [block]

        BlockConversion.convert(block, to: .paragraph)

        #expect(block.attributes.headingLevel == nil)
    }

    // MARK: - Attributs : `isChecked` toujours preserve, meme en sortant de `todo`

    @Test("convert(_:to:) preserve isChecked en sortant de todo, et le retrouve au retour")
    func convertPreservesIsCheckedAcrossRoundTrip() {
        let note = Note(title: "Test")
        var attributes = BlockAttributes()
        attributes.isChecked = true
        let block = Block(
            order: 0, type: .todo, text: RichText(plainText: "Acheter du pain"), attributes: attributes, note: note
        )
        note.blocks = [block]

        BlockConversion.convert(block, to: .paragraph)
        #expect(block.type == .paragraph)
        #expect(block.attributes.isChecked == true) // volontairement PRESERVE (voir BlockConversion)

        BlockConversion.convert(block, to: .todo)
        #expect(block.attributes.isChecked == true)
    }

    // MARK: - Attributs : abandon documente des champs type-dependants (`language`)

    @Test("convert(_:to:) abandonne volontairement le langage d'un bloc code en le quittant")
    func convertOutOfCodeDropsLanguage() {
        let note = Note(title: "Test")
        var attributes = BlockAttributes()
        attributes.language = "swift"
        let block = Block(
            order: 0, type: .code, text: RichText(plainText: "let x = 1"), attributes: attributes, note: note
        )
        note.blocks = [block]

        BlockConversion.convert(block, to: .paragraph)
        #expect(block.attributes.language == nil) // perte VOLONTAIRE, voir BlockConversion

        BlockConversion.convert(block, to: .code)
        #expect(block.attributes.language == nil) // ne ressuscite pas un langage perime
    }

    // MARK: - Conversions entre les trois types de liste : imbrication preservee

    @Test("convert(_:to:) entre types de liste preserve les enfants et leur imbrication")
    func convertBetweenListTypesPreservesChildren() {
        let note = Note(title: "Test")
        let list = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Parent"), note: note)
        let child = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: list)
        list.children = [child]
        note.blocks = [list, child]

        BlockConversion.convert(list, to: .todo)

        #expect(list.type == .todo)
        #expect(BlockOrdering.children(of: list).map(\.id) == [child.id])
        #expect(child.parent?.id == list.id)

        BlockConversion.convert(list, to: .numberedList)

        #expect(list.type == .numberedList)
        #expect(BlockOrdering.children(of: list).map(\.id) == [child.id])
        #expect(child.parent?.id == list.id)
    }

    // MARK: - Conversion d'un bloc a enfants vers un type qui n'en porte pas : promotion

    @Test("convert(_:to:) vers un type non-liste PROMEUT les enfants comme freres suivants")
    func convertToNonListTypePromotesChildren() {
        let note = Note(title: "Test")
        let list = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Parent"), note: note)
        let childA = Block(order: 0, type: .bulletedList, text: RichText(plainText: "A"), note: note, parent: list)
        let childB = Block(order: 1, type: .bulletedList, text: RichText(plainText: "B"), note: note, parent: list)
        list.children = [childA, childB]
        let after = Block(order: 1, type: .paragraph, text: RichText(plainText: "Apres"), note: note)
        note.blocks = [list, childA, childB, after]

        BlockConversion.convert(list, to: .heading1)

        #expect(list.type == .heading1)
        #expect(BlockOrdering.children(of: list).isEmpty)
        #expect(childA.parent == nil)
        #expect(childB.parent == nil)

        let topLevel = BlockOrdering.topLevelBlocks(of: note)
        #expect(topLevel.map(\.text?.plainText) == ["Parent", "A", "B", "Apres"])
    }

    // MARK: - Types non offerts (pas de rendu textuel reel, ou reserves a une phase ulterieure)

    @Test("availableTargets(for:) est vide pour un type non convertible (divider)")
    func availableTargetsEmptyForNonConvertibleType() {
        let note = Note(title: "Test")
        let divider = Block(order: 0, type: .divider, note: note)
        note.blocks = [divider]

        #expect(BlockConversion.availableTargets(for: divider).isEmpty)
    }

    @Test("availableTargets(for:) ne propose jamais le type courant, ni un type non rendu")
    func availableTargetsExcludesCurrentTypeAndUnrenderedTypes() {
        let note = Note(title: "Test")
        let paragraph = Block(order: 0, type: .paragraph, text: RichText(plainText: "Texte"), note: note)
        note.blocks = [paragraph]

        let targets = BlockConversion.availableTargets(for: paragraph)

        #expect(!targets.contains(.paragraph))
        #expect(!targets.contains(.table))
        #expect(!targets.contains(.callout))
        #expect(!targets.contains(.image))
        #expect(targets.contains(.heading1))
        #expect(targets.contains(.todo))
    }

    @Test("convert(_:to:) sans effet si le type cible n'est pas convertible")
    func convertNoOpForNonConvertibleTarget() {
        let note = Note(title: "Test")
        let paragraph = Block(order: 0, type: .paragraph, text: RichText(plainText: "Texte"), note: note)
        note.blocks = [paragraph]

        BlockConversion.convert(paragraph, to: .table)

        #expect(paragraph.type == .paragraph)
    }

    // MARK: - Helpers

    private func headingType(forLevel level: Int) -> BlockType {
        switch level {
        case 1: .heading1
        case 2: .heading2
        case 3: .heading3
        case 4: .heading4
        case 5: .heading5
        default: .heading6
        }
    }
}

import Testing

@testable import SlateEditor

@Suite("WordCounter")
struct WordCounterTests {
    @Test("Une chaine vide compte 0 mot")
    func emptyStringCountsZero() {
        #expect(WordCounter.wordCount(in: "") == 0)
    }

    @Test("Une chaine entierement blanche compte 0 mot")
    func whitespaceOnlyCountsZero() {
        #expect(WordCounter.wordCount(in: "   \n\t  ") == 0)
    }

    @Test("Compte les mots separes par des espaces simples")
    func countsSimpleWords() {
        #expect(WordCounter.wordCount(in: "Bonjour le monde") == 3)
    }

    @Test("Les sauts de ligne et espaces multiples separent aussi les mots")
    func countsAcrossNewlinesAndMultipleSpaces() {
        #expect(WordCounter.wordCount(in: "Titre\n\nUn   paragraphe   ici.") == 4)
    }
}

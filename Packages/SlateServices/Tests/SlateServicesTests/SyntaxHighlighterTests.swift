import Testing
@testable import SlateServices

// Chemins critiques du colorateur (docs/08). On ne teste pas la grammaire complete des
// langages : le lexeur n'y pretend pas (voir l'en-tete de `SyntaxHighlighting.swift`). On
// verrouille ce qui casserait visiblement le rendu ou provoquerait une boucle.

/// Confort de lecture : recompose la liste des (role, texte) pour un source donne.
private func roles(_ source: String, _ language: SyntaxLanguage) -> [(SyntaxTokenRole, String)] {
    SyntaxHighlighter.tokens(for: source, language: language)
        .map { ($0.role, String(source[$0.range])) }
}

@Suite("Colorateur syntaxique")
struct SyntaxHighlighterTests {
    @Test("Un mot-cle, un type, un nombre et une chaine sont distingues")
    func distinguishesBasicRoles() {
        let result = roles("let count: Int = 42 + valeur(\"texte\")", .swift)
        #expect(result.contains { $0 == .keyword && $1 == "let" })
        #expect(result.contains { $0 == .type && $1 == "Int" })
        #expect(result.contains { $0 == .number && $1 == "42" })
        #expect(result.contains { $0 == .string && $1 == "\"texte\"" })
        // `count` et `valeur` ne sont ni mots-cles ni types : aucun token, donc rendus en
        // couleur de texte par defaut.
        #expect(!result.contains { $1 == "count" })
        #expect(!result.contains { $1 == "valeur" })
    }

    @Test("Un chiffre dans un identifiant n'est pas colore comme un nombre")
    func doesNotColorDigitsInsideIdentifiers() {
        let result = roles("let note1 = 1", .swift)
        let numbers = result.filter { $0.0 == .number }
        #expect(numbers.count == 1)
        #expect(numbers.first?.1 == "1")
    }

    @Test("Un guillemet echappe ne ferme pas la chaine")
    func escapedQuoteDoesNotCloseString() {
        let result = roles("let s = \"un \\\" guillemet\"", .swift)
        let strings = result.filter { $0.0 == .string }
        #expect(strings.count == 1)
        #expect(strings.first?.1 == "\"un \\\" guillemet\"")
    }

    @Test("Un mot-cle a l'interieur d'un commentaire reste du commentaire")
    func keywordInsideCommentStaysComment() {
        let result = roles("// let struct func\nlet x = 1", .swift)
        #expect(result.first?.0 == .comment)
        #expect(result.first?.1 == "// let struct func")
        // Le `let` apres le saut de ligne, lui, est bien un mot-cle.
        #expect(result.contains { $0 == .keyword && $1 == "let" })
    }

    @Test("Un commentaire de bloc non ferme ne provoque pas de boucle infinie")
    func unterminatedBlockCommentTerminates() {
        let result = roles("/* jamais ferme", .swift)
        #expect(result.count == 1)
        #expect(result.first?.0 == .comment)
    }

    @Test("Une chaine non fermee s'arrete en fin de ligne")
    func unterminatedStringStopsAtEndOfLine() {
        let result = roles("let s = \"ouvert\nlet t = 2", .swift)
        #expect(result.contains { $0 == .string && $1 == "\"ouvert" })
        // La ligne suivante est relue normalement, elle n'est pas avalee par la chaine.
        #expect(result.contains { $0 == .number && $1 == "2" })
    }

    @Test("Le guillemet simple delimite une chaine en JavaScript, pas en Swift")
    func singleQuoteIsLanguageDependent() {
        #expect(roles("const s = 'texte'", .javascript).contains { $0 == .string && $1 == "'texte'" })
        #expect(!roles("let s = 'texte'", .swift).contains { $0.0 == .string })
    }

    @Test("Le diese est un commentaire en Python mais une directive en Swift")
    func hashIsLanguageDependent() {
        #expect(roles("# un commentaire", .python).first?.0 == .comment)
        // En Swift, `#if` est un mot-cle, surtout pas un commentaire jusqu'a la fin de ligne.
        let swiftResult = roles("#if DEBUG", .swift)
        #expect(swiftResult.contains { $0 == .keyword && $1 == "#if" })
        #expect(!swiftResult.contains { $0.0 == .comment })
    }

    @Test("Une chaine multiligne Python est un seul token")
    func pythonTripleQuotedStringIsOneToken() {
        let source = "x = \"\"\"une\ndocstring\"\"\"\ny = 1"
        let result = roles(source, .python)
        let strings = result.filter { $0.0 == .string }
        #expect(strings.count == 1)
        #expect(strings.first?.1.contains("docstring") == true)
        #expect(result.contains { $0 == .number && $1 == "1" })
    }

    @Test("JSON colore ses trois litteraux et ses cles")
    func jsonColorsLiteralsAndKeys() {
        let result = roles("{\"actif\": true, \"n\": 3, \"vide\": null}", .json)
        #expect(result.contains { $0 == .keyword && $1 == "true" })
        #expect(result.contains { $0 == .keyword && $1 == "null" })
        #expect(result.contains { $0 == .string && $1 == "\"actif\"" })
        #expect(result.contains { $0 == .number && $1 == "3" })
    }

    @Test("Le texte brut ne produit aucun token")
    func plainTextProducesNoTokens() {
        #expect(SyntaxHighlighter.tokens(for: "let struct 42 // rien", language: .plainText).isEmpty)
    }

    @Test("Les portions sont ordonnees et ne se chevauchent jamais")
    func tokensAreOrderedAndDisjoint() {
        let source = """
        // en-tete
        struct Vue: View {
            let titre = "Bonjour"
            var n = 12
        }
        """
        let tokens = SyntaxHighlighter.tokens(for: source, language: .swift)
        #expect(tokens.count > 4)
        for (previous, next) in zip(tokens, tokens.dropFirst()) {
            #expect(previous.range.upperBound <= next.range.lowerBound)
        }
    }

    @Test("Un source vide ou un langage inconnu ne fait pas echouer la resolution")
    func emptyAndUnknownInputsAreSafe() {
        #expect(SyntaxHighlighter.tokens(for: "", language: .swift).isEmpty)
        #expect(SyntaxLanguage.resolve(nil) == .swift)
        #expect(SyntaxLanguage.resolve("langage-du-futur") == .swift)
        #expect(SyntaxLanguage.resolve("python") == .python)
    }

    @Test("Un accent ou un emoji dans le source ne decale pas les portions")
    func multiByteCharactersKeepRangesValid() {
        // Regression attendue si un jour le lexeur passait aux offsets entiers : les
        // `String.Index` restent valides quel que soit l'encodage des caracteres.
        let source = "let ete = \"cafe et gateau\" // resume"
        for token in SyntaxHighlighter.tokens(for: source, language: .swift) {
            #expect(token.range.lowerBound >= source.startIndex)
            #expect(token.range.upperBound <= source.endIndex)
        }
        #expect(roles(source, .swift).contains { $0 == .string && $1 == "\"cafe et gateau\"" })
    }
}

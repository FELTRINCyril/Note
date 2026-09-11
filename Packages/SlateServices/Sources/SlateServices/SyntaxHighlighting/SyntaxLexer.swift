import Foundation

// Lexeur en une passe pour la coloration des blocs de code. Voir l'en-tete de
// `SyntaxHighlighting.swift` pour le cadre et la portee assumee.

/// Parcourt le source une seule fois et emet les portions colorees.
///
/// Structure mutable interne au module : elle porte la position courante du curseur, ce
/// qui evite de repasser des index en parametre a chaque etape.
struct SyntaxLexer {
    private let source: String
    private let language: SyntaxLanguage
    private var index: String.Index
    private var tokens: [SyntaxToken] = []

    init(source: String, language: SyntaxLanguage) {
        self.source = source
        self.language = language
        self.index = source.startIndex
    }

    mutating func scan() -> [SyntaxToken] {
        while index < source.endIndex {
            let character = source[index]

            if let token = scanComment() {
                tokens.append(token)
            } else if let token = scanString() {
                tokens.append(token)
            } else if character.isNumber, isAtTokenStart() {
                tokens.append(scanNumber())
            } else if character.isLetter || character == "_" || character == "@" || character == "#" {
                if let token = scanWord() {
                    tokens.append(token)
                }
            } else {
                advance()
            }
        }
        return tokens
    }

    // MARK: - Curseur

    private mutating func advance() {
        index = source.index(after: index)
    }

    /// Vrai si le caractere precedent ne peut pas faire partie d'un identifiant.
    ///
    /// Evite de colorer le "1" de `note1` comme un nombre.
    private func isAtTokenStart() -> Bool {
        guard index > source.startIndex else { return true }
        let previous = source[source.index(before: index)]
        return !(previous.isLetter || previous.isNumber || previous == "_")
    }

    private func matches(_ prefix: String) -> Bool {
        source[index...].hasPrefix(prefix)
    }

    // MARK: - Commentaires

    private mutating func scanComment() -> SyntaxToken? {
        let start = index

        // Commentaire de ligne. `#` est aussi le prefixe des directives Swift
        // (`#available`) : on ne le traite comme un commentaire qu'en Python.
        let lineMarker: String? = switch language {
        case .swift, .javascript: "//"
        case .python: "#"
        case .json, .plainText: nil
        }
        if let lineMarker, matches(lineMarker) {
            while index < source.endIndex, !source[index].isNewline {
                advance()
            }
            return SyntaxToken(role: .comment, range: start..<index)
        }

        // Commentaire de bloc, non imbrique (Swift autorise l'imbrication, mais la gerer
        // n'apporterait rien de visible ici).
        guard language == .swift || language == .javascript, matches("/*") else { return nil }
        advance()
        advance()
        while index < source.endIndex, !matches("*/") {
            advance()
        }
        if index < source.endIndex {
            advance()
            advance()
        }
        return SyntaxToken(role: .comment, range: start..<index)
    }

    // MARK: - Chaines

    private mutating func scanString() -> SyntaxToken? {
        let character = source[index]

        // Chaine multiligne Python. Traitee avant la chaine simple, sinon `"""` serait lu
        // comme une chaine vide suivie d'un guillemet orphelin.
        if language == .python, matches("\"\"\"") || matches("'''") {
            let delimiter = String(source[index..<source.index(index, offsetBy: 3)])
            let start = index
            for _ in 0..<3 { advance() }
            while index < source.endIndex, !matches(delimiter) {
                advance()
            }
            if index < source.endIndex {
                for _ in 0..<3 where index < source.endIndex { advance() }
            }
            return SyntaxToken(role: .string, range: start..<index)
        }

        // Le guillemet simple delimite une chaine en JavaScript et en Python, mais pas en
        // Swift ni en JSON.
        let singleQuoteOpens = language == .javascript || language == .python
        let backtickOpens = character == "`" && language == .javascript
        guard character == "\"" || (character == "'" && singleQuoteOpens) || backtickOpens else {
            return nil
        }

        let start = index
        advance()
        while index < source.endIndex {
            let current = source[index]
            if current == "\\" {
                // Echappement : on saute le caractere suivant, sinon `"\""` fermerait la
                // chaine trop tot.
                advance()
                if index < source.endIndex { advance() }
                continue
            }
            if current == character {
                advance()
                break
            }
            // Une chaine non terminee s'arrete en fin de ligne, sauf gabarit JavaScript
            // (backtick) qui est legitimement multiligne.
            if current.isNewline, character != "`" {
                break
            }
            advance()
        }
        return SyntaxToken(role: .string, range: start..<index)
    }

    // MARK: - Nombres

    private mutating func scanNumber() -> SyntaxToken {
        let start = index
        var hasSeparator = false
        while index < source.endIndex {
            let current = source[index]
            if current.isHexDigit || current == "_" || current == "x" || current == "b" || current == "o" {
                advance()
            } else if current == "." && !hasSeparator {
                // Un seul point : `1.2` est un nombre, le second point de `1.2.3` arrete.
                hasSeparator = true
                advance()
            } else {
                break
            }
        }
        return SyntaxToken(role: .number, range: start..<index)
    }

    // MARK: - Mots

    private mutating func scanWord() -> SyntaxToken? {
        let start = index
        // Le prefixe d'attribut/decorateur fait partie du mot : `@State`, `@Observable`.
        if source[index] == "@" || source[index] == "#" {
            advance()
        }
        while index < source.endIndex, source[index].isLetter || source[index].isNumber || source[index] == "_" {
            advance()
        }
        let word = String(source[start..<index])
        guard !word.isEmpty else {
            // Un `@` ou `#` isole : on l'a deja consomme, ne pas boucler dessus.
            if index == start { advance() }
            return nil
        }

        if SyntaxKeywords.isKeyword(word, in: language) {
            return SyntaxToken(role: .keyword, range: start..<index)
        }
        // Heuristique de type : majuscule initiale. Couvre les conventions de Swift, de
        // JavaScript et de Python sans avoir a resoudre les portees.
        if let first = word.first, first.isUppercase {
            return SyntaxToken(role: .type, range: start..<index)
        }
        // Attribut ou decorateur non repertorie (`@MainActor` est un mot-cle connu,
        // `@MonAttribut` non) : reste signale comme un type, c'est la teinte la plus
        // proche visuellement.
        if word.hasPrefix("@") || word.hasPrefix("#") {
            return SyntaxToken(role: .type, range: start..<index)
        }
        return nil
    }
}

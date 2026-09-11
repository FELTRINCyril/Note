import Foundation

// Listes de mots-cles par langage, pour le lexeur de coloration.
//
// Volontairement non exhaustives : elles couvrent ce qu'on rencontre en pratique dans un
// bloc de code d'une note. Un mot-cle absent est simplement rendu en texte ordinaire, ce
// qui est sans consequence fonctionnelle.

enum SyntaxKeywords {
    static func isKeyword(_ word: String, in language: SyntaxLanguage) -> Bool {
        switch language {
        case .swift: swift.contains(word)
        case .javascript: javascript.contains(word)
        case .python: python.contains(word)
        case .json: json.contains(word)
        case .plainText: false
        }
    }

    private static let swift: Set<String> = [
        "actor", "as", "associatedtype", "async", "await", "break", "case", "catch",
        "class", "consuming", "continue", "convenience", "default", "defer", "deinit",
        "didSet", "do", "dynamic", "else", "enum", "extension", "fallthrough", "false",
        "fileprivate", "final", "for", "func", "get", "guard", "if", "import", "in",
        "indirect", "infix", "init", "inout", "internal", "is", "lazy", "let", "mutating",
        "nil", "nonisolated", "nonmutating", "open", "operator", "optional", "override",
        "postfix", "precedencegroup", "prefix", "private", "protocol", "public",
        "repeat", "required", "rethrows", "return", "self", "sending", "set", "some",
        "static", "struct", "subscript", "super", "switch", "throw", "throws", "true",
        "try", "typealias", "unowned", "var", "weak", "where", "while", "willSet", "yield",
        "@MainActor", "@Observable", "@State", "@Binding", "@Environment", "@escaping",
        "@Sendable", "@ViewBuilder", "@Model", "@Attribute", "@Relationship", "@Transient",
        "@Query", "@discardableResult", "@available", "#available", "#if", "#else",
        "#endif", "#selector", "#expect", "#require"
    ]

    private static let javascript: Set<String> = [
        "async", "await", "break", "case", "catch", "class", "const", "continue",
        "debugger", "default", "delete", "do", "else", "export", "extends", "false",
        "finally", "for", "from", "function", "get", "if", "import", "in", "instanceof",
        "let", "new", "null", "of", "return", "set", "static", "super", "switch", "this",
        "throw", "true", "try", "typeof", "undefined", "var", "void", "while", "with",
        "yield"
    ]

    private static let python: Set<String> = [
        "and", "as", "assert", "async", "await", "break", "class", "continue", "def",
        "del", "elif", "else", "except", "False", "finally", "for", "from", "global",
        "if", "import", "in", "is", "lambda", "None", "nonlocal", "not", "or", "pass",
        "raise", "return", "True", "try", "while", "with", "yield", "self"
    ]

    // JSON n'a pas de mots-cles au sens strict : seuls les trois litteraux du format.
    private static let json: Set<String> = ["true", "false", "null"]
}

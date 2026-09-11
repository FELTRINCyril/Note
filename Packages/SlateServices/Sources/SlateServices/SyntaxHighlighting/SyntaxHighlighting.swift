import Foundation

// Coloration syntaxique des blocs de code (docs/08_blocs_speciaux.md, artboard E du
// design P1).
//
// Choix tranche en phase 8 : colorateur MAISON minimal, pas de bibliotheque tierce
// (Highlightr, Splash...). Deux raisons. D'abord CLAUDE.md §6 interdit d'ajouter une
// dependance tierce sans accord prealable. Ensuite le besoin reel est modeste : le design
// n'expose que 5 langages et 6 roles de token, la ou ces bibliotheques en embarquent des
// centaines avec leurs propres themes de couleur, qu'il faudrait de toute facon mapper sur
// les tokens `code.syntax.*` de `design/tokens.md` §16 ter.
//
// Ce module vit dans `SlateServices` : aucune notion d'UI, donc aucune couleur ici. Un
// role de token est neutre (`SyntaxTokenRole`), c'est `SlateUI` qui le resout en couleur
// via `SlateSyntaxToken`, exactement comme pour le surlignage inline en phase 7. Le pont
// entre les deux se fait par `rawValue`.
//
// Portee assumee : c'est un lexeur, pas un parseur. Il ne connait pas la grammaire des
// langages et ne cherche pas a la connaitre. Il reconnait commentaires, chaines, nombres,
// mots-cles et identifiants a majuscule initiale. Sur du code volontairement tordu il se
// trompera parfois de teinte, ce qui n'a aucune consequence : le texte reste intact et
// lisible, seule sa couleur est approximative.

/// Role semantique d'une portion de code, sous forme neutre (aucune couleur).
///
/// Les `rawValue` correspondent aux cas de `SlateSyntaxToken` cote `SlateUI`, qui porte
/// les couleurs de `design/tokens.md` §16 ter. Un test verrouille cette correspondance
/// cote `SlateEditor`, seul module a voir les deux.
public enum SyntaxTokenRole: String, Sendable, Hashable, CaseIterable {
    case plain
    case keyword
    case string
    case number
    case type
    case comment
}

/// Une portion de source et son role.
///
/// La position est un `Range<String.Index>` et non une paire d'entiers : c'est la regle du
/// projet (aucun `Int` nu pour une position de texte, voir `RichTextOffset` en phase 5).
/// Le passage vers AppKit se fait par `NSRange(token.range, in: source)`, qui gere seul la
/// conversion UTF-16.
public struct SyntaxToken: Sendable, Hashable {
    public let role: SyntaxTokenRole
    public let range: Range<String.Index>

    public init(role: SyntaxTokenRole, range: Range<String.Index>) {
        self.role = role
        self.range = range
    }
}

/// Langages proposes par le selecteur du bloc de code (artboard E).
///
/// `rawValue` est persiste dans `BlockAttributes.language` : ne jamais le modifier une fois
/// des notes ecrites, le langage retomberait silencieusement sur le defaut au decodage.
public enum SyntaxLanguage: String, Sendable, Hashable, CaseIterable {
    case swift
    case javascript
    case python
    case json
    case plainText

    /// Langage par defaut d'un nouveau bloc de code (le design montre "Swift" preselectionne).
    public static let `default`: SyntaxLanguage = .swift

    /// Resout un identifiant persiste, en retombant sur le defaut plutot qu'en echouant :
    /// une note ecrite par une version future de l'app, avec un langage inconnu de
    /// celle-ci, doit rester lisible.
    public static func resolve(_ identifier: String?) -> SyntaxLanguage {
        guard let identifier else { return .default }
        return SyntaxLanguage(rawValue: identifier) ?? .default
    }
}

/// Colorateur syntaxique. Sans etat, purement fonctionnel.
public enum SyntaxHighlighter {
    /// Decoupe `source` en portions colorees.
    ///
    /// Les portions retournees sont dans l'ordre du texte et ne se chevauchent pas. Les
    /// portions de role `plain` sont omises : tout ce qui n'est couvert par aucun token
    /// est du texte ordinaire, a rendre avec la couleur de texte par defaut. Ca evite de
    /// produire un token par espace.
    public static func tokens(for source: String, language: SyntaxLanguage) -> [SyntaxToken] {
        guard language != .plainText, !source.isEmpty else { return [] }
        var lexer = SyntaxLexer(source: source, language: language)
        return lexer.scan()
    }
}

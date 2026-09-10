import Foundation

/// Contenu texte riche d'un bloc (`Block.text`, voir docs/02_modele_donnees.md).
///
/// Encapsule un `AttributedString` natif (option 1 du doc, tranchee par l'orchestrateur :
/// pas de modele maison de "runs"). Porte le formatage inline : gras, italique, souligne,
/// barre, code inline, surlignage, lien.
///
/// ## Persistance SwiftData / CloudKit
/// `RichText` est `Codable`, ce qui suffit pour etre stocke tel quel comme propriete d'un
/// `@Model` SwiftData : SwiftData persiste un type `Codable` non-primitif en l'encodant en
/// blob binaire (JSON) dans la colonne. C'est compatible CloudKit (un blob est une valeur
/// scalaire ordinaire du point de vue du store), a condition de garder la propriete
/// optionnelle ou avec valeur par defaut cote `@Model`, comme toute propriete CloudKit.
///
/// ## Le piege du round-trip Codable
/// `AttributedString` ne conforme pas a `Codable` "tout court" : son
/// encodage/decodage est parametre par un `AttributeScope` (via `CodableWithConfiguration`,
/// `JSONEncoder.encode(_:configuration:)` / `JSONDecoder.decode(_:from:configuration:)`).
/// Si on encode/decode avec un scope qui ne connait pas nos attributs custom (ex: le scope
/// `Foundation` seul), ceux-ci sont **silencieusement** ignores : pas d'erreur, juste une
/// perte de donnees au decodage. Il faut donc explicitement utiliser
/// `AttributeScopes.SlateAttributes` (voir SlateInlineAttributes.swift), qui regroupe nos
/// attributs custom ET le scope `Foundation` (gras/italique/barre via
/// `InlinePresentationIntent`, lien via `LinkAttribute`). C'est ce scope qui est passe en
/// configuration ci-dessous, jamais un `AttributedString` encode "brut".
public struct RichText: Codable, Hashable, Sendable {
    public var attributedString: AttributedString

    public init(attributedString: AttributedString) {
        self.attributedString = attributedString
    }

    /// Texte riche vide.
    public init() {
        self.attributedString = AttributedString()
    }

    /// Depuis un texte brut, sans aucun attribut.
    public init(plainText: String) {
        self.attributedString = AttributedString(plainText)
    }

    /// Texte brut, sans attributs. Utilise pour la recherche plein texte (Phase 15) :
    /// aucun predicat SwiftData ne peut filtrer directement sur un `AttributedString`
    /// serialise en blob, d'ou ce champ derive, expose ici pour rester a un seul endroit.
    public var plainText: String {
        String(attributedString.characters)
    }

    public var isEmpty: Bool {
        attributedString.characters.isEmpty
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case attributedString
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attributedString = try container.decode(
            AttributedString.self,
            forKey: .attributedString,
            configuration: AttributeScopes.SlateAttributes.self
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            attributedString,
            forKey: .attributedString,
            configuration: AttributeScopes.SlateAttributes.self
        )
    }
}

// MARK: - Marques de formatage inline

/// Une marque de formatage inline applicable/retirable sur une plage de `RichText`.
///
/// API volontairement minimale : l'editeur de blocs (Phase 5, `SlateEditor`) construira
/// par-dessus (raccourcis clavier, barre flottante, etc.). On ne cherche pas a anticiper
/// ses besoins ici.
public enum InlineMark: Hashable, Sendable {
    case bold
    case italic
    case underline
    case strikethrough
    case inlineCode
    case highlight(SlateHighlightColor)
    case textColor(SlateTextColor)
    case link(URL)
}

extension RichText {
    /// Applique une marque sur la plage donnee, en preservant les autres marques deja
    /// presentes sur cette meme plage (ex: appliquer `.italic` sur une plage deja en gras
    /// donne du gras + italique, pas juste de l'italique).
    public mutating func apply(_ mark: InlineMark, to range: Range<AttributedString.Index>) {
        switch mark {
        case .bold:
            unionInlinePresentationIntent(.stronglyEmphasized, in: range)
        case .italic:
            unionInlinePresentationIntent(.emphasized, in: range)
        case .strikethrough:
            unionInlinePresentationIntent(.strikethrough, in: range)
        case .underline:
            attributedString[range].slateUnderline = true
        case .inlineCode:
            attributedString[range].slateInlineCode = true
        case let .highlight(color):
            attributedString[range].slateHighlight = color
        case let .textColor(color):
            attributedString[range].slateTextColor = color
        case let .link(url):
            attributedString[range].link = url
        }
    }

    /// Retire une marque de la plage donnee. Le payload associe (couleur de surlignage,
    /// URL du lien) est ignore : seule la nature de la marque compte pour la suppression.
    public mutating func remove(_ mark: InlineMark, from range: Range<AttributedString.Index>) {
        switch mark {
        case .bold:
            subtractInlinePresentationIntent(.stronglyEmphasized, in: range)
        case .italic:
            subtractInlinePresentationIntent(.emphasized, in: range)
        case .strikethrough:
            subtractInlinePresentationIntent(.strikethrough, in: range)
        case .underline:
            attributedString[range].slateUnderline = nil
        case .inlineCode:
            attributedString[range].slateInlineCode = nil
        case .highlight:
            attributedString[range].slateHighlight = nil
        case .textColor:
            attributedString[range].slateTextColor = nil
        case .link:
            attributedString[range].link = nil
        }
    }

    /// Convertit un intervalle d'offsets en `Character` (pratique pour piloter l'API par
    /// entiers, notamment dans les tests) en intervalle d'indices `AttributedString`.
    public func range(charactersOffset offsets: Range<Int>) -> Range<AttributedString.Index> {
        let lower = attributedString.characters.index(
            attributedString.startIndex,
            offsetBy: offsets.lowerBound
        )
        let upper = attributedString.characters.index(
            attributedString.startIndex,
            offsetBy: offsets.upperBound
        )
        return lower..<upper
    }

    private mutating func unionInlinePresentationIntent(
        _ intent: InlinePresentationIntent,
        in range: Range<AttributedString.Index>
    ) {
        let existing = attributedString[range].inlinePresentationIntent ?? []
        attributedString[range].inlinePresentationIntent = existing.union(intent)
    }

    private mutating func subtractInlinePresentationIntent(
        _ intent: InlinePresentationIntent,
        in range: Range<AttributedString.Index>
    ) {
        guard let existing = attributedString[range].inlinePresentationIntent else { return }
        let remaining = existing.subtracting(intent)
        attributedString[range].inlinePresentationIntent = remaining.isEmpty ? nil : remaining
    }
}

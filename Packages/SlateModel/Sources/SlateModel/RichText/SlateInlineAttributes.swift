import Foundation

// Attributs custom d'`AttributedString` pour le formatage inline de Slate (voir
// docs/02_modele_donnees.md, section "Formatage inline").
//
// Rappel d'architecture (docs/00_architecture.md) : SlateModel ne connait aucune notion
// d'UI. On importe donc uniquement `Foundation` ici, jamais `SwiftUI` ni `AppKit`/`UIKit`.
// Consequence directe : la couleur de surlignage est stockee sous forme neutre
// (`SlateHighlightColor`, un simple wrapper de `String`), jamais comme un `Color`. C'est
// la couche `SlateUI`/`SlateEditor` qui resoudra ce token en couleur concrete au rendu.
//
// Deuxieme consequence : `Foundation` ne fournit pas nativement d'attribut de
// soulignement pour `AttributedString`. `InlinePresentationIntent` (le mecanisme Foundation
// qui porte gras/italique/barre/code) ne comporte pas de cas "underline" - seuls
// AppKit/UIKit en fournissent un (`.underlineStyle`), et ces frameworks sont interdits ici.
// Le soulignement est donc, comme le surlignage et le code inline, un attribut custom
// Slate (`SlateUnderlineAttribute`), au meme titre que les deux autres.

// MARK: - Surlignage (highlight)

/// Couleur de surlignage, sous forme neutre et serialisable.
///
/// `value` porte soit un nom de token de design (ex: `"yellow"`, `"slateHighlightYellow"`),
/// soit une chaine hex (ex: `"#FFEE88"`). La distinction entre les deux formes et leur
/// resolution en couleur concrete sont a la charge de la couche UI (`SlateUI`), jamais de
/// `SlateModel`.
public struct SlateHighlightColor: Codable, Hashable, Sendable {
    public var value: String

    public init(_ value: String) {
        self.value = value
    }
}

/// Attribut portant la couleur de surlignage d'une portion de texte.
public struct SlateHighlightAttribute: CodableAttributedStringKey, AttributedStringKey {
    public typealias Value = SlateHighlightColor

    // ATTENTION : cette chaine est le nom serialise (JSON) de l'attribut. Elle est
    // persistee avec chaque note ecrite en base. Ne JAMAIS la modifier une fois des
    // donnees existent en production : un changement ferait perdre silencieusement le
    // surlignage de toutes les notes existantes au decodage (la cle ne serait plus
    // reconnue, l'attribut serait simplement absent, sans erreur).
    public static let name = "slateHighlight"
}

// MARK: - Code inline

/// Marqueur booleen : la portion de texte est rendue comme du code inline
/// (typiquement police monospace, fond distinct).
public struct SlateInlineCodeAttribute: CodableAttributedStringKey, AttributedStringKey {
    public typealias Value = Bool

    // ATTENTION : nom stable, voir le commentaire sur `SlateHighlightAttribute.name`.
    public static let name = "slateInlineCode"
}

// MARK: - Soulignement

/// Marqueur booleen : la portion de texte est soulignee.
///
/// Attribut custom car Foundation ne fournit pas de cle native pour le soulignement
/// (voir le commentaire d'en-tete de ce fichier).
public struct SlateUnderlineAttribute: CodableAttributedStringKey, AttributedStringKey {
    public typealias Value = Bool

    // ATTENTION : nom stable, voir le commentaire sur `SlateHighlightAttribute.name`.
    public static let name = "slateUnderline"
}

// MARK: - AttributeScope

extension AttributeScopes {
    /// Scope regroupant les attributs custom de Slate (surlignage, code inline,
    /// soulignement) AVEC le scope `Foundation` natif.
    ///
    /// Piege principal du formatage inline (voir RichText.swift) : l'encodage Codable
    /// d'un `AttributedString` ne preserve QUE les attributs connus du scope explicitement
    /// passe en configuration a l'encodeur/decodeur. Si ce scope ne regroupe pas aussi
    /// `Foundation` (qui porte le gras/l'italique/le barre via `InlinePresentationIntent`,
    /// et le lien via `LinkAttribute`), ces attributs standard seraient silencieusement
    /// perdus au round-trip, exactement comme le seraient nos attributs custom si on
    /// utilisait le scope `Foundation` seul. D'ou ce scope combine, unique source de
    /// verite pour toute (de)serialisation dans `SlateModel`.
    public struct SlateAttributes: AttributeScope {
        public let slateHighlight: SlateHighlightAttribute
        public let slateInlineCode: SlateInlineCodeAttribute
        public let slateUnderline: SlateUnderlineAttribute
        public let foundation: AttributeScopes.FoundationAttributes
    }

    /// Point d'entree pratique : `AttributeScopes.slate`.
    public var slate: SlateAttributes.Type { SlateAttributes.self }
}

extension AttributeDynamicLookup {
    /// Permet l'acces par point (`attributedString[range].slateHighlight`,
    /// `.slateInlineCode`, `.slateUnderline`, mais aussi `.inlinePresentationIntent`,
    /// `.link` via le sous-scope `foundation` imbrique) sur les attributs du scope Slate.
    public subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.SlateAttributes, T>
    ) -> T {
        self[T.self]
    }
}

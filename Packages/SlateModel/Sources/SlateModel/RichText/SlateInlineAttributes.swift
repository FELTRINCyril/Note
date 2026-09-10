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
///
/// Conforme aussi a `ObjectiveCConvertibleAttributedStringKey` : sans cela, le pont
/// `AttributedString` <-> `NSAttributedString` (utilise par tout `NSTextView`/`UITextView`,
/// donc par l'editeur en TextKit 2) ignore silencieusement cet attribut - il n'est ni
/// leve en erreur ni journalise, il disparait simplement au retour du pont. Voir
/// `SlateInlineAttributesObjectiveCBridgeTests` qui encode ce defaut avant correctif.
public struct SlateHighlightAttribute: CodableAttributedStringKey, AttributedStringKey,
    ObjectiveCConvertibleAttributedStringKey {
    public typealias Value = SlateHighlightColor
    public typealias ObjectiveCValue = NSString

    // ATTENTION : cette chaine est le nom serialise (JSON) de l'attribut. Elle est
    // persistee avec chaque note ecrite en base. Ne JAMAIS la modifier une fois des
    // donnees existent en production : un changement ferait perdre silencieusement le
    // surlignage de toutes les notes existantes au decodage (la cle ne serait plus
    // reconnue, l'attribut serait simplement absent, sans erreur).
    public static let name = "slateHighlight"

    /// `SlateHighlightColor` est un simple wrapper de `String` : transport naturel via
    /// `NSString`. Aucune conversion ne peut echouer ici (toute `String` est une
    /// `NSString` valide), mais la signature du protocole impose `throws` : on la respecte
    /// pour rester coherent avec les autres attributs Slate et pour ne jamais avoir a
    /// revenir sur cette signature si le format de `SlateHighlightColor` se complexifie.
    public static func objectiveCValue(for value: SlateHighlightColor) throws -> NSString {
        value.value as NSString
    }

    public static func value(for object: NSString) throws -> SlateHighlightColor {
        SlateHighlightColor(object as String)
    }
}

// MARK: - Couleur de texte

/// Couleur de texte inline, sous forme neutre et serialisable.
///
/// Meme forme et meme raisonnement que `SlateHighlightColor` : `value` porte soit un nom
/// de token de design, soit une chaine hex, et la resolution en couleur concrete est a la
/// charge de la couche UI (`SlateUI`), jamais de `SlateModel`.
public struct SlateTextColor: Codable, Hashable, Sendable {
    public var value: String

    public init(_ value: String) {
        self.value = value
    }
}

/// Attribut portant la couleur de texte d'une portion de texte.
///
/// Conforme aussi a `ObjectiveCConvertibleAttributedStringKey`, pour la meme raison que
/// `SlateHighlightAttribute` : sans cela, le pont `AttributedString` <-> `NSAttributedString`
/// ignore silencieusement cet attribut. Voir `SlateInlineAttributesObjectiveCBridgeTests`.
public struct SlateTextColorAttribute: CodableAttributedStringKey, AttributedStringKey,
    ObjectiveCConvertibleAttributedStringKey {
    public typealias Value = SlateTextColor
    public typealias ObjectiveCValue = NSString

    // ATTENTION : cette chaine est le nom serialise (JSON) de l'attribut. Elle est
    // persistee avec chaque note ecrite en base. Ne JAMAIS la modifier une fois des
    // donnees existent en production, voir le commentaire sur `SlateHighlightAttribute.name`.
    public static let name = "slateTextColor"

    /// Voir le commentaire equivalent sur `SlateHighlightAttribute.objectiveCValue(for:)` :
    /// cette conversion ne peut pas echouer.
    public static func objectiveCValue(for value: SlateTextColor) throws -> NSString {
        value.value as NSString
    }

    public static func value(for object: NSString) throws -> SlateTextColor {
        SlateTextColor(object as String)
    }
}

// MARK: - Code inline

/// Marqueur booleen : la portion de texte est rendue comme du code inline
/// (typiquement police monospace, fond distinct).
///
/// Conforme a `ObjectiveCConvertibleAttributedStringKey`, voir le commentaire equivalent
/// sur `SlateHighlightAttribute`.
public struct SlateInlineCodeAttribute: CodableAttributedStringKey, AttributedStringKey,
    ObjectiveCConvertibleAttributedStringKey {
    public typealias Value = Bool
    public typealias ObjectiveCValue = NSNumber

    // ATTENTION : nom stable, voir le commentaire sur `SlateHighlightAttribute.name`.
    public static let name = "slateInlineCode"

    /// `Bool` <-> `NSNumber` ne peut pas echouer dans les deux sens : `NSNumber(value:)`
    /// accepte tout `Bool`, et `.boolValue` est defini pour tout `NSNumber`. `throws` est
    /// impose par la signature du protocole ; on ne l'utilise donc jamais ici, mais on
    /// documente ce fait plutot que de le laisser implicite.
    public static func objectiveCValue(for value: Bool) throws -> NSNumber {
        NSNumber(value: value)
    }

    public static func value(for object: NSNumber) throws -> Bool {
        object.boolValue
    }
}

// MARK: - Soulignement

/// Marqueur booleen : la portion de texte est soulignee.
///
/// Attribut custom car Foundation ne fournit pas de cle native pour le soulignement
/// (voir le commentaire d'en-tete de ce fichier).
///
/// Conforme a `ObjectiveCConvertibleAttributedStringKey`, voir le commentaire equivalent
/// sur `SlateHighlightAttribute`.
public struct SlateUnderlineAttribute: CodableAttributedStringKey, AttributedStringKey,
    ObjectiveCConvertibleAttributedStringKey {
    public typealias Value = Bool
    public typealias ObjectiveCValue = NSNumber

    // ATTENTION : nom stable, voir le commentaire sur `SlateHighlightAttribute.name`.
    public static let name = "slateUnderline"

    /// Voir le commentaire equivalent sur `SlateInlineCodeAttribute` : cette conversion
    /// ne peut pas echouer, dans aucun des deux sens.
    public static func objectiveCValue(for value: Bool) throws -> NSNumber {
        NSNumber(value: value)
    }

    public static func value(for object: NSNumber) throws -> Bool {
        object.boolValue
    }
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
        public let slateTextColor: SlateTextColorAttribute
        public let slateInlineCode: SlateInlineCodeAttribute
        public let slateUnderline: SlateUnderlineAttribute
        public let foundation: AttributeScopes.FoundationAttributes
    }

    /// Point d'entree pratique : `AttributeScopes.slate`.
    public var slate: SlateAttributes.Type { SlateAttributes.self }
}

extension AttributeDynamicLookup {
    /// Permet l'acces par point (`attributedString[range].slateHighlight`,
    /// `.slateTextColor`, `.slateInlineCode`, `.slateUnderline`, mais aussi
    /// `.inlinePresentationIntent`,
    /// `.link` via le sous-scope `foundation` imbrique) sur les attributs du scope Slate.
    public subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.SlateAttributes, T>
    ) -> T {
        self[T.self]
    }
}

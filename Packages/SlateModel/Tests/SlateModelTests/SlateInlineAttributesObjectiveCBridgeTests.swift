import Foundation
import Testing

@testable import SlateModel

// Cette suite encode le defaut signale par l'orchestrateur (perte silencieuse des trois
// attributs custom Slate - surlignage, code inline, souligne - au passage par
// `NSAttributedString`, tel qu'exige par tout `NSTextView` TextKit 2), puis prouve que le
// correctif (conformance a `ObjectiveCConvertibleAttributedStringKey` sur les trois
// attributs) le resout - a une condition IMPORTANTE, mesuree en ecrivant cette suite et
// documentee au fil du fichier : le pont doit etre fait en precisant explicitement le scope
// `AttributeScopes.SlateAttributes`. Voir le rapport de l'agent pour le detail de cette
// condition et son impact sur `SlateEditor` (hors perimetre de ce package).
//
// AVANT le correctif (attributs custom conformes seulement a `CodableAttributedStringKey`,
// pas a `ObjectiveCConvertibleAttributedStringKey`) :
//   - le round-trip JSON (voir RichTextTests) passe : `Codable` ne depend pas du pont ObjC.
//   - le round-trip scope `AttributeScopes.SlateAttributes` -> `NSAttributedString` ->
//     `AttributeScopes.SlateAttributes` preserve le TEXTE et la VALEUR de chaque attribut
//     custom, mais en la boxant dans un `__SwiftValue` opaque (verifie avec
//     `NSAttributedString.attributes(at:effectiveRange:)` pendant l'ecriture de cette
//     suite) : ce n'est pas un vrai objet Objective-C, seulement un conteneur Swift qui ne
//     survivrait pas a un usage reel du pont (RTF/RTFD, pasteboard, accessibilite,
//     `NSCoding`/undo manager).
//   - le round-trip SANS scope explicite (`NSAttributedString(_:)` / `AttributedString(_:)`,
//     tel qu'utilise aujourd'hui par `RichTextBlockView.swift` dans `SlateEditor`) perd
//     silencieusement les trois attributs custom, AVANT COMME APRES le correctif de ce
//     fichier : seul le gras survit (`inlinePresentationIntent`, deja natif Foundation).
//     Voir `whenBridgedWithoutExplicitScopeCustomMarksAreStillLostEvenAfterTheFix` ci-dessous.
//
// APRES le correctif, avec le scope explicite : les trois attributs custom sont transportes
// comme de vrais objets Objective-C (`NSString`/`NSNumber`, verifie pendant l'ecriture de
// cette suite), sur la bonne plage, avec la bonne valeur - exactement comme `link`
// (`NSURL`) ou le gras (`NSNumber` via `InlinePresentationIntentAttribute`) le sont deja
// nativement.
@Suite("SlateInlineAttributes - pont Objective-C (NSAttributedString)")
struct SlateInlineAttributesObjectiveCBridgeTests {

    /// Fait passer un `RichText` par le pont Objective-C en precisant explicitement le
    /// scope `AttributeScopes.SlateAttributes` - c'est la maniere correcte de faire ce pont
    /// pour un `AttributedString` qui porte des attributs custom (recommandation de
    /// l'API Foundation : sans scope precise, l'init "par defaut" ne considere que le
    /// scope `Foundation` natif, quelle que soit la conformance des cles custom - voir le
    /// test dedie plus bas). C'est le chemin que `SlateEditor` doit utiliser pour que le
    /// correctif de ce fichier ait un effet reel a l'usage.
    private func roundTripThroughScopedObjectiveCBridge(_ text: RichText) throws -> RichText {
        let nsAttributedString = try NSAttributedString(
            text.attributedString,
            including: AttributeScopes.SlateAttributes.self
        )
        let backAgain = try AttributedString(
            nsAttributedString,
            including: AttributeScopes.SlateAttributes.self
        )
        return RichText(attributedString: backAgain)
    }

    @Test(
        "gras + lien + surlignage + code inline + souligne survivent tous au pont scope, sur la bonne plage"
    )
    func allFiveMarksSurviveScopedBridgeOnCorrectRanges() throws {
        // "Bonjour le monde ici" (20 caracteres)
        //  01234567890123456789
        // gras       : [8..14)  -> "le mon"
        // lien       : [11..17) -> "monde " (chevauche le gras sur [11..14))
        // surlignage : [0..7)   -> "Bonjour"
        // code inline: [8..14)  -> "le mon" (meme plage que le gras)
        // souligne   : [17..20) -> "ici" (disjointe de toutes les autres)
        var text = RichText(plainText: "Bonjour le monde ici")
        let boldRange = text.range(charactersOffset: 8..<14)
        let linkRange = text.range(charactersOffset: 11..<17)
        let highlightRange = text.range(charactersOffset: 0..<7)
        let codeRange = text.range(charactersOffset: 8..<14)
        let underlineRange = text.range(charactersOffset: 17..<20)
        let url = try #require(URL(string: "https://kreaddis.com"))
        let color = SlateHighlightColor("yellow")

        text.apply(.bold, to: boldRange)
        text.apply(.link(url), to: linkRange)
        text.apply(.highlight(color), to: highlightRange)
        text.apply(.inlineCode, to: codeRange)
        text.apply(.underline, to: underlineRange)

        let bridged = try roundTripThroughScopedObjectiveCBridge(text)

        #expect(bridged.plainText == "Bonjour le monde ici")

        let bridgedBoldRange = bridged.range(charactersOffset: 8..<14)
        let bridgedLinkRange = bridged.range(charactersOffset: 11..<17)
        let bridgedHighlightRange = bridged.range(charactersOffset: 0..<7)
        let bridgedCodeRange = bridged.range(charactersOffset: 8..<14)
        let bridgedUnderlineRange = bridged.range(charactersOffset: 17..<20)

        #expect(bridged.attributedString[bridgedBoldRange].inlinePresentationIntent == .stronglyEmphasized)
        #expect(bridged.attributedString[bridgedLinkRange].link == url)
        #expect(bridged.attributedString[bridgedHighlightRange].slateHighlight == color)
        #expect(bridged.attributedString[bridgedCodeRange].slateInlineCode == true)
        #expect(bridged.attributedString[bridgedUnderlineRange].slateUnderline == true)

        // Les attributs ne doivent pas avoir "deborde" hors de leur plage d'origine.
        let beforeHighlight = bridged.range(charactersOffset: 7..<8)
        #expect(bridged.attributedString[beforeHighlight].slateHighlight == nil)

        let beforeUnderline = bridged.range(charactersOffset: 14..<17)
        #expect(bridged.attributedString[beforeUnderline].slateUnderline == nil)

        let afterBoldCode = bridged.range(charactersOffset: 14..<15)
        #expect(bridged.attributedString[afterBoldCode].inlinePresentationIntent == nil)
        #expect(bridged.attributedString[afterBoldCode].slateInlineCode == nil)
    }

    @Test("plages partiellement chevauchantes preservees au pont scope (gras/lien/surlignage)")
    func overlappingRangesSurviveScopedBridge() throws {
        // Meme configuration de plages que RichTextTests.boldLinkHighlightRoundTrip, mais
        // via le pont Objective-C plutot que via le JSON.
        var text = RichText(plainText: "Bonjour le monde ici")
        let boldRange = text.range(charactersOffset: 8..<14)
        let linkRange = text.range(charactersOffset: 11..<17)
        let highlightRange = text.range(charactersOffset: 0..<7)
        let url = try #require(URL(string: "https://kreaddis.com"))
        let color = SlateHighlightColor("#FFEE88")

        text.apply(.bold, to: boldRange)
        text.apply(.link(url), to: linkRange)
        text.apply(.highlight(color), to: highlightRange)

        let bridged = try roundTripThroughScopedObjectiveCBridge(text)

        // Zone de chevauchement gras/lien : les deux doivent etre presents a la fois.
        let overlap = bridged.range(charactersOffset: 11..<14)
        #expect(bridged.attributedString[overlap].inlinePresentationIntent == .stronglyEmphasized)
        #expect(bridged.attributedString[overlap].link == url)

        // Partie du lien hors chevauchement : lien seul, pas de gras.
        let linkOnly = bridged.range(charactersOffset: 14..<17)
        #expect(bridged.attributedString[linkOnly].link == url)
        #expect(bridged.attributedString[linkOnly].inlinePresentationIntent == nil)

        // Surlignage sur une plage disjointe : ne doit pas avoir migre.
        let highlightOnly = bridged.range(charactersOffset: 0..<7)
        #expect(bridged.attributedString[highlightOnly].slateHighlight == color)
        let afterHighlight = bridged.range(charactersOffset: 7..<8)
        #expect(bridged.attributedString[afterHighlight].slateHighlight == nil)
    }

    @Test("la couleur de surlignage transportee est la bonne valeur, pas juste une presence")
    func highlightColorValueSurvivesScopedBridgeExactly() throws {
        var text = RichText(plainText: "important")
        let range = text.range(charactersOffset: 0..<9)
        text.apply(.highlight(SlateHighlightColor("yellow")), to: range)

        let bridged = try roundTripThroughScopedObjectiveCBridge(text)
        let bridgedRange = bridged.range(charactersOffset: 0..<9)

        let transported = bridged.attributedString[bridgedRange].slateHighlight
        #expect(transported == SlateHighlightColor("yellow"))
        #expect(transported?.value == "yellow")
        // Non-regression explicite du defaut signale : la valeur n'a pas ete degradee en
        // simple booleen ni perdue en chaine vide.
        #expect(transported?.value.isEmpty == false)
        #expect(transported?.value != "true")
    }

    @Test("code inline et souligne survivent individuellement au pont scope (sans les autres marques)")
    func inlineCodeAndUnderlineAloneSurviveScopedBridge() throws {
        var text = RichText(plainText: "swift six")
        let codeRange = text.range(charactersOffset: 0..<5)
        let underlineRange = text.range(charactersOffset: 6..<9)

        text.apply(.inlineCode, to: codeRange)
        text.apply(.underline, to: underlineRange)

        let bridged = try roundTripThroughScopedObjectiveCBridge(text)

        let bridgedCodeRange = bridged.range(charactersOffset: 0..<5)
        let bridgedUnderlineRange = bridged.range(charactersOffset: 6..<9)

        #expect(bridged.attributedString[bridgedCodeRange].slateInlineCode == true)
        #expect(bridged.attributedString[bridgedUnderlineRange].slateUnderline == true)

        // Aucune contamination croisee entre les deux attributs.
        #expect(bridged.attributedString[bridgedCodeRange].slateUnderline == nil)
        #expect(bridged.attributedString[bridgedUnderlineRange].slateInlineCode == nil)
    }

    @Test("le transport Objective-C est un vrai objet ObjC (NSString/NSNumber), pas un box Swift opaque")
    func transportedValuesAreGenuineObjectiveCObjects() throws {
        // Preuve que le correctif ne se contente pas de "faire passer" la valeur par un
        // `__SwiftValue` opaque (ce qui se produisait avant le correctif, verifie pendant
        // l'ecriture de cette suite) : les valeurs sont de vrais `NSString`/`NSNumber`,
        // aptes a un usage Objective-C reel (RTF, pasteboard, accessibilite...), pas
        // seulement a un aller-retour Swift-vers-Swift dans le meme process.
        var text = RichText(plainText: "hello")
        let range = text.range(charactersOffset: 0..<5)
        text.apply(.highlight(SlateHighlightColor("yellow")), to: range)
        text.apply(.inlineCode, to: range)
        text.apply(.underline, to: range)

        let nsAttributedString = try NSAttributedString(
            text.attributedString,
            including: AttributeScopes.SlateAttributes.self
        )
        let attributes = nsAttributedString.attributes(at: 0, effectiveRange: nil)

        let highlightValue = try #require(attributes[NSAttributedString.Key(SlateHighlightAttribute.name)])
        let codeValue = try #require(attributes[NSAttributedString.Key(SlateInlineCodeAttribute.name)])
        let underlineValue = try #require(attributes[NSAttributedString.Key(SlateUnderlineAttribute.name)])

        // `is NSString`/`is NSNumber` echouerait si la valeur etait encore boxee dans un
        // `__SwiftValue` opaque (comportement observe avant le correctif) : ces deux
        // classes sont de vrais types Objective-C, jamais celui d'un box Swift.
        #expect(highlightValue is NSString)
        #expect(codeValue is NSNumber)
        #expect(underlineValue is NSNumber)
    }

    @Test("la couleur de texte survit au pont scope, avec la bonne valeur")
    func textColorSurvivesScopedBridgeExactly() throws {
        var text = RichText(plainText: "important")
        let range = text.range(charactersOffset: 0..<9)
        text.apply(.textColor(SlateTextColor("#112233")), to: range)

        let bridged = try roundTripThroughScopedObjectiveCBridge(text)
        let bridgedRange = bridged.range(charactersOffset: 0..<9)

        let transported = bridged.attributedString[bridgedRange].slateTextColor
        #expect(transported == SlateTextColor("#112233"))
        #expect(transported?.value == "#112233")
    }

    @Test("la couleur de texte cumulee avec le surlignage survit au pont scope, sans se contaminer")
    func textColorAndHighlightBothSurviveScopedBridge() throws {
        var text = RichText(plainText: "important")
        let range = text.range(charactersOffset: 0..<9)
        text.apply(.highlight(SlateHighlightColor("yellow")), to: range)
        text.apply(.textColor(SlateTextColor("#112233")), to: range)

        let bridged = try roundTripThroughScopedObjectiveCBridge(text)
        let bridgedRange = bridged.range(charactersOffset: 0..<9)

        #expect(bridged.attributedString[bridgedRange].slateHighlight == SlateHighlightColor("yellow"))
        #expect(bridged.attributedString[bridgedRange].slateTextColor == SlateTextColor("#112233"))
    }

    // MARK: - Limite mesuree du correctif : le pont SANS scope explicite reste casse

    @Test(
        """
        SANS scope explicite (le chemin utilise aujourd'hui par RichTextBlockView dans \
        SlateEditor), les marques custom restent perdues meme apres le correctif de ce \
        fichier - seul le gras (Foundation natif) survit
        """
    )
    func whenBridgedWithoutExplicitScopeCustomMarksAreStillLostEvenAfterTheFix() {
        // Ce test documente une LIMITE du correctif, pas le correctif lui-meme : il prouve
        // que la conformance ObjectiveC ajoutee dans SlateInlineAttributes.swift est une
        // condition NECESSAIRE mais PAS SUFFISANTE. Le code reel de `SlateEditor`
        // (`RichTextBlockView.swift`) appelle `NSAttributedString(text.attributedString)`
        // et `AttributedString(textView.textStorage ?? NSTextStorage())`, SANS jamais
        // preciser `including: AttributeScopes.SlateAttributes.self`. Verifie ici que ce
        // chemin particulier perd toujours silencieusement les attributs custom, meme avec
        // le correctif applique - il faut donc AUSSI faire evoluer `SlateEditor` pour
        // preciser le scope explicitement (voir le rapport de l'agent).
        var text = RichText(plainText: "hello")
        let range = text.range(charactersOffset: 0..<5)
        text.apply(.bold, to: range)
        text.apply(.highlight(SlateHighlightColor("yellow")), to: range)
        text.apply(.textColor(SlateTextColor("#112233")), to: range)
        text.apply(.inlineCode, to: range)
        text.apply(.underline, to: range)

        let nsAttributedString = NSAttributedString(text.attributedString) // pas de scope
        let backAgain = AttributedString(nsAttributedString) // pas de scope
        let bridged = RichText(attributedString: backAgain)
        let bridgedRange = bridged.range(charactersOffset: 0..<5)

        #expect(bridged.plainText == "hello")
        // Le gras (Foundation natif) survit : c'est la reference qui montre que le pont
        // fonctionne en general, seuls nos attributs custom sont affectes.
        #expect(bridged.attributedString[bridgedRange].inlinePresentationIntent == .stronglyEmphasized)

        // Les attributs custom Slate sont perdus par ce chemin, sans aucune erreur.
        #expect(bridged.attributedString[bridgedRange].slateHighlight == nil)
        #expect(bridged.attributedString[bridgedRange].slateTextColor == nil)
        #expect(bridged.attributedString[bridgedRange].slateInlineCode == nil)
        #expect(bridged.attributedString[bridgedRange].slateUnderline == nil)
    }

    // MARK: - Non-regression : le round-trip JSON de la phase 2 ne doit pas etre affecte
    // par la conformance ObjectiveC ajoutee ici (elle s'ajoute a `CodableAttributedStringKey`,
    // elle ne le remplace pas).
    @Test("le round-trip JSON reste intact apres l'ajout de la conformance Objective-C")
    func jsonRoundTripStillWorksAfterObjectiveCConformanceAdded() throws {
        var text = RichText(plainText: "abcdef")
        let range = text.range(charactersOffset: 0..<6)

        text.apply(.highlight(SlateHighlightColor("yellow")), to: range)
        text.apply(.textColor(SlateTextColor("#112233")), to: range)
        text.apply(.inlineCode, to: range)
        text.apply(.underline, to: range)

        let encoded = try JSONEncoder().encode(text)
        let decoded = try JSONDecoder().decode(RichText.self, from: encoded)

        #expect(decoded == text)
        #expect(decoded.attributedString[range].slateHighlight == SlateHighlightColor("yellow"))
        #expect(decoded.attributedString[range].slateTextColor == SlateTextColor("#112233"))
        #expect(decoded.attributedString[range].slateInlineCode == true)
        #expect(decoded.attributedString[range].slateUnderline == true)
    }
}

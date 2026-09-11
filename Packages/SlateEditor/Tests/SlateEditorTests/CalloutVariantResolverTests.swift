import SlateUI
import Testing

@testable import SlateEditor

/// `CalloutVariantResolver` : pont `BlockAttributes.calloutVariant` (`String?`) ->
/// `SlateCalloutVariant`. Verrouille le repli sur `.neutral` -- meme raison que
/// `SyntaxHighlightingCorrespondenceTests` : une divergence de `rawValue`, ou l'oubli du
/// repli sur une valeur inconnue, casserait silencieusement le rendu d'une note ecrite
/// par une version passee/future de l'app.
@Suite("CalloutVariantResolver")
struct CalloutVariantResolverTests {
    @Test("nil retombe sur .neutral (valeur par defaut d'un callout jamais configure)")
    func nilFallsBackToNeutral() {
        #expect(CalloutVariantResolver.resolve(nil) == .neutral)
    }

    @Test("Un identifiant INCONNU retombe sur .neutral, jamais une erreur")
    func unknownIdentifierFallsBackToNeutral() {
        #expect(CalloutVariantResolver.resolve("une-variante-future-inconnue") == .neutral)
    }

    @Test("Chaque SlateCalloutVariant.rawValue se resout vers lui-meme")
    func everyVariantRawValueRoundTrips() {
        for variant in SlateCalloutVariant.allCases {
            #expect(CalloutVariantResolver.resolve(variant.rawValue) == variant)
        }
    }
}

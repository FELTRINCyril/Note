import Foundation
import SlateServices
import SlateUI
import Testing

@testable import SlateEditor

/// Verrouille la correspondance entre `SyntaxTokenRole` (`SlateServices`, neutre, sans
/// couleur) et `SlateSyntaxToken` (`SlateUI`, porte les couleurs) : `SlateEditor` est le
/// SEUL module a dependre des deux (voir la documentation de tete de
/// `SyntaxHighlighting.swift`, `SlateServices`), donc le SEUL endroit ou une divergence
/// de `rawValue` entre les deux enums pourrait etre detectee -- sans ce test, un
/// renommage/ajout d'un cas d'un cote sans l'autre rendrait le bloc de code
/// silencieusement MONOCHROME (le `SlateSyntaxToken(rawValue:)` de
/// `RichTextEditingRepresentable+Rendering.swift` echouerait pour ce role et l'ignorerait,
/// sans jamais planter ni avertir).
@Suite("Correspondance SyntaxTokenRole <-> SlateSyntaxToken")
struct SyntaxHighlightingCorrespondenceTests {
    @Test("Chaque SyntaxTokenRole a un SlateSyntaxToken de meme rawValue")
    func everyServiceRoleHasAMatchingUIToken() {
        for role in SyntaxTokenRole.allCases {
            let hasMatch = SlateSyntaxToken(rawValue: role.rawValue) != nil
            #expect(hasMatch, "Role sans couleur correspondante : \(role.rawValue)")
        }
    }

    @Test("Chaque SlateSyntaxToken a un SyntaxTokenRole de meme rawValue (aucun orphelin cote UI)")
    func everyUITokenHasAMatchingServiceRole() {
        for token in SlateSyntaxToken.allCases {
            let hasMatch = SyntaxTokenRole(rawValue: token.rawValue) != nil
            #expect(hasMatch, "Couleur sans role de service correspondant : \(token.rawValue)")
        }
    }

    @Test("Les deux enums ont exactement le meme nombre de cas")
    func sameCaseCount() {
        #expect(SyntaxTokenRole.allCases.count == SlateSyntaxToken.allCases.count)
    }

    @Test("Un token du lexeur se mappe vers un NSRange valide sur le texte source reel")
    func tokenRangeMapsToValidNSRangeOnRealText() {
        let source = "let value = 42 // un commentaire\nfunc greet(name: String) -> String { \"Bonjour \\(name)\" }"
        let tokens = SyntaxHighlighter.tokens(for: source, language: .swift)

        #expect(!tokens.isEmpty)
        let sourceLength = (source as NSString).length
        for token in tokens {
            let nsRange = NSRange(token.range, in: source)
            #expect(nsRange.location != NSNotFound)
            #expect(NSMaxRange(nsRange) <= sourceLength)
            // Chaque role transporte est bien resolvable en couleur reelle -- pas
            // seulement en theorie via `SyntaxTokenRole.allCases` ci-dessus.
            #expect(SlateSyntaxToken(rawValue: token.role.rawValue) != nil)
        }
    }

    @Test("Un texte sans aucun mot-cle/chaine/nombre reconnu ne produit aucun token (role plain omis)")
    func plainTextProducesNoTokens() {
        let tokens = SyntaxHighlighter.tokens(for: "un texte quelconque sans syntaxe", language: .plainText)
        #expect(tokens.isEmpty)
    }
}

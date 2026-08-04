import Foundation

/// Position dans un `RichText`, exprimee en offset de GRAPHEMES (`Character` d'
/// `AttributedString`/`String`), JAMAIS en unites UTF-16 (`NSString`/`NSAttributedString`
/// /`NSRange`, l'unite native de tout `NSTextView`/`UITextView`).
///
/// ## Le defaut corrige ici (revue finale de Phase 5)
/// `NSTextView.selectedRange().location` est TOUJOURS en unites UTF-16 (API
/// `NSAttributedString`), alors que `BlockLifecycle`/`RichText.split(at:)` attendent un
/// offset en `Character` (grapheme). Les deux coincident pour du texte latin simple et
/// DIVERGENT SILENCIEUSEMENT des qu'un caractere avant l'offset occupe plus d'une unite
/// UTF-16 (emoji hors du plan Unicode de base, la plupart des drapeaux, certains
/// sinogrammes rares...) : le split/la jointure se produit alors au mauvais endroit,
/// sans crash, sans log. Un `Int` nu ne peut pas empecher cette confusion a la
/// compilation -- c'est exactement ce qui l'a laissee vivre jusqu'a cette revue.
///
/// ## Convention retenue pour toute la logique pure de cet editeur
/// Toute position ou etendue de texte qui traverse la frontiere AppKit/UIKit -> logique
/// pure (`BlockLifecycle`, `EditorController`, `EditorCaretRequest`) doit desormais etre
/// un `RichTextOffset` (position ponctuelle) ou un `RichTextRange` (etendue -- voir ce
/// type : necessaire DES CETTE PHASE, pas seulement pour le caret. La Phase 7
/// (formatage inline) appliquera du gras a une PLAGE selectionnee, pas seulement a un
/// caret ponctuel -- la convention est concue pour ce besoin dès maintenant, meme si
/// rien dans la Phase 5 n'utilise encore `RichTextRange`). Plus aucune fonction de ce
/// module ne doit accepter un `Int` nu pour une position/etendue de texte.
///
/// La SEULE facon de construire un `RichTextOffset` a partir d'un offset UTF-16 (donc de
/// franchir la frontiere AppKit -> pur) passe par `init(utf16Offset:in:)`, qui documente
/// et effectue explicitement la conversion. Symmetriquement, `utf16Offset(in:)` est la
/// SEULE facon de repousser une position vers AppKit (`NSTextView.setSelectedRange(_:)`).
///
/// ## `ExpressibleByIntegerLiteral` : un compromis delibere, pas une porte de derobade
/// Ce type conforme a `ExpressibleByIntegerLiteral` pour que `RichTextOffset(characters: 7)`
/// puisse s'ecrire `7` a un site d'appel qui attend un `RichTextOffset` (tests, valeurs
/// constantes comme `.offset(0)`) -- SANS affaiblir la garantie : un LITTERAL entier
/// (`7`) est une valeur connue au moment de la compilation, jamais le resultat d'un
/// calcul AppKit (`selectedRange().location` est une VARIABLE, pas un litteral -- elle
/// ne peut PAS satisfaire `ExpressibleByIntegerLiteral`, la conversion explicite via
/// `init(utf16Offset:in:)` reste donc obligatoire pour elle). Le risque reel identifie
/// par la revue -- un `Int` VARIABLE d'origine UTF-16 glissant sans conversion dans un
/// contexte "Characters" -- reste impossible a la compilation.
public struct RichTextOffset: Hashable, Sendable, Comparable {
    /// Offset en `Character` (grapheme), l'unite native d'`AttributedString.characters`
    /// et de `RichText.split(at:)`.
    public let characters: Int

    public init(characters: Int) {
        self.characters = characters
    }

    /// Construit un offset de caracteres a partir d'un offset UTF-16
    /// (`NSRange.location`, tel que rapporte par `NSTextView.selectedRange()`) : le SEUL
    /// point d'entree autorise pour franchir la frontiere AppKit -> logique pure.
    ///
    /// Implemente par une simple avancee grapheme par grapheme de `string` (JAMAIS via
    /// `NSString`/les vues UTF-16 de `String.Index`, pour rester correct meme si
    /// `utf16Offset` retombe -- par construction impossible depuis un vrai `NSTextView`,
    /// mais defensif -- au milieu d'une paire de substituts) : s'arrete au premier
    /// `Character` dont ajouter la largeur UTF-16 depasserait `utf16Offset`, ce qui borne
    /// implicitement le resultat a `[0, string.count]` sans jamais planter.
    public init(utf16Offset: Int, in string: String) {
        guard utf16Offset > 0 else {
            self.characters = 0
            return
        }
        var remainingUTF16 = utf16Offset
        var characterCount = 0
        for character in string {
            let width = String(character).utf16.count
            if remainingUTF16 < width {
                break
            }
            remainingUTF16 -= width
            characterCount += 1
        }
        self.characters = characterCount
    }

    /// Offset UTF-16 (`NSRange.location`) correspondant, dans `string` -- le SEUL point
    /// de sortie autorise pour repousser une position vers AppKit
    /// (`NSTextView.setSelectedRange(_:)`). Borne a `[0, string.count]` avant de sommer
    /// les largeurs UTF-16, jamais un index invalide possible.
    public func utf16Offset(in string: String) -> Int {
        let clampedCharacters = max(0, min(characters, string.count))
        var utf16Total = 0
        for character in string.prefix(clampedCharacters) {
            utf16Total += String(character).utf16.count
        }
        return utf16Total
    }

    public static func < (lhs: RichTextOffset, rhs: RichTextOffset) -> Bool {
        lhs.characters < rhs.characters
    }
}

extension RichTextOffset: ExpressibleByIntegerLiteral {
    /// Voir la documentation de tete de fichier, section "un compromis delibere" :
    /// UNIQUEMENT satisfaisable par un litteral entier ecrit en dur au site d'appel,
    /// jamais par une variable (ex: `selectedRange().location`).
    public init(integerLiteral value: Int) {
        self.characters = value
    }
}

/// Etendue de texte dans un `RichText`, en offsets de CARACTERES (`RichTextOffset`) --
/// generalisation d'une position ponctuelle a une plage, necessaire des cette Phase 5
/// (voir la documentation de `RichTextOffset`) pour que la Phase 7 (formatage inline
/// applique a une SELECTION, pas seulement a un caret) reutilise directement cette
/// convention sans avoir a la reinventer avec ses propres unites.
public struct RichTextRange: Hashable, Sendable {
    public let lowerBound: RichTextOffset
    public let upperBound: RichTextOffset

    /// Borne implicitement `lowerBound <= upperBound` en les echangeant au besoin --
    /// jamais un `precondition`/crash pour une paire construite dans le mauvais ordre.
    public init(lowerBound: RichTextOffset, upperBound: RichTextOffset) {
        if lowerBound <= upperBound {
            self.lowerBound = lowerBound
            self.upperBound = upperBound
        } else {
            self.lowerBound = upperBound
            self.upperBound = lowerBound
        }
    }

    /// Plage vide (caret ponctuel) a `offset` -- convenance pour les appelants qui
    /// traitent encore un caret comme un cas particulier de plage.
    public init(caret offset: RichTextOffset) {
        self.lowerBound = offset
        self.upperBound = offset
    }

    /// Construit une plage a partir d'un `NSRange` (unites UTF-16, tel que rapporte par
    /// `NSTextView.selectedRange()`) et du contenu `string` qu'il indexe -- le SEUL point
    /// d'entree autorise pour franchir la frontiere AppKit -> logique pure pour une
    /// PLAGE (symmetrique de `RichTextOffset.init(utf16Offset:in:)` pour un caret ponctuel).
    public init(utf16Range: NSRange, in string: String) {
        let lower = RichTextOffset(utf16Offset: utf16Range.location, in: string)
        let upper = RichTextOffset(utf16Offset: utf16Range.location + utf16Range.length, in: string)
        self.lowerBound = lower
        self.upperBound = upper
    }

    /// `true` pour un caret ponctuel (aucun texte selectionne).
    public var isEmpty: Bool { lowerBound == upperBound }
}

import Foundation
import SlateModel

/// Scission d'un `RichText` en deux, en preservant les attributs inline de chaque
/// moitie (gras, italique, surlignage, lien... voir `SlateInlineAttributes`).
///
/// Ajoutee ICI, dans `SlateEditor`, et non dans `SlateModel` (perimetre gele de cet
/// agent pour cette sous-etape) : `RichText` reste un type public ordinaire de
/// `SlateModel`, cette extension ne fait qu'ajouter une operation consommatrice, sans
/// toucher a sa definition ni a son round-trip `Codable`.
///
/// Implementee EXCLUSIVEMENT via `AttributedString` (tranchage d'un `Substring`
/// attribue, puis reconstruction) : jamais via `String`/`plainText`, qui perdrait tout
/// formatage (docs/05_editeur_blocs.md, sous-etape 5.3 : "le split doit preserver les
/// ATTRIBUTS inline de chaque moitie").
extension RichText {
    /// Scinde ce texte riche a l'offset de CARACTERES donne (`RichTextOffset`, jamais un
    /// `Int` nu -- voir sa documentation) : `head` porte `[0, offset)`, `tail` porte
    /// `[offset, longueur)`. `offset` est borne a `[0, longueur]` : aucun index invalide
    /// possible, quel que soit l'appelant.
    func split(atCharacterOffset offset: RichTextOffset) -> (head: RichText, tail: RichText) {
        let characters = attributedString.characters
        let clamped = max(0, min(offset.characters, characters.count))
        let splitIndex = characters.index(characters.startIndex, offsetBy: clamped)

        let headSlice = attributedString[attributedString.startIndex..<splitIndex]
        let tailSlice = attributedString[splitIndex..<attributedString.endIndex]

        return (
            head: RichText(attributedString: AttributedString(headSlice)),
            tail: RichText(attributedString: AttributedString(tailSlice))
        )
    }
}

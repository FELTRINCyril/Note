import SlateUI

/// Pont `String` (persiste dans `BlockAttributes.calloutVariant`, `SlateModel`) ->
/// `SlateCalloutVariant` (`SlateUI`, qui porte les couleurs/l'icone/le libelle) --
/// EXACTEMENT le meme motif que `SyntaxLanguage.resolve(_:)` (`SlateServices`) pour le
/// langage d'un bloc code, et que la resolution d'un jeton de surlignage en Phase 7 :
/// `SlateEditor` est le seul module a voir a la fois `BlockAttributes` et
/// `SlateCalloutVariant`, donc le seul endroit ou verrouiller cette correspondance (voir
/// `CalloutVariantResolutionTests`).
///
/// `nil` ou un identifiant INCONNU retombent TOUJOURS sur `.neutral`, jamais une erreur --
/// une note ecrite par une version FUTURE de l'app, avec une variante que celle-ci ne
/// connait pas encore, doit rester lisible (meme garantie documentee sur
/// `BlockAttributes`, section "Conception pour l'extensibilite").
enum CalloutVariantResolver {
    static func resolve(_ identifier: String?) -> SlateCalloutVariant {
        guard let identifier else { return .neutral }
        return SlateCalloutVariant(rawValue: identifier) ?? .neutral
    }
}

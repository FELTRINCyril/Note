import SlateModel
import SlateUI

/// Traduction entre `DatabaseSelectOption.colorToken` (chaine neutre cote `SlateModel`,
/// voir sa documentation de tete : "`SlateModel` ne connait aucune notion d'apparence")
/// et `SlateAccentColor` (palette reelle, `SlateUI`). Vit ici, dans `SlateFeatures`,
/// exactement pour cette raison : ni `SlateModel` ni `SlateUI` ne doivent connaitre
/// l'autre.
enum DatabaseColorToken {
    /// Valeur de secours pour un token inconnu (compatibilite ascendante si un token
    /// est renomme un jour) : rendu neutre plutot qu'un crash ou une couleur au hasard.
    static func accent(for colorToken: String) -> SlateAccentColor? {
        guard colorToken != Self.neutralToken else { return nil }
        return SlateAccentColor(rawValue: colorToken)
    }

    static func colorToken(for accent: SlateAccentColor?) -> String {
        accent?.rawValue ?? Self.neutralToken
    }

    /// Tous les tokens proposables dans l'editeur de champ (les 8 accents + le neutre),
    /// dans un ordre stable pour l'affichage.
    static var assignableTokens: [String] {
        [Self.neutralToken] + SlateAccentColor.allCases.map(\.rawValue)
    }

    static let neutralToken = "neutral"
}

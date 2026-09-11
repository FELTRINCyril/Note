import SwiftUI
import SlateUI

/// Robustesse d'un mot de passe de verrouillage saisi dans `SetPasswordSheet` (design
/// P3, artboard C : jauge colonne + mot ("Robuste") -- "jamais une barre coloree
/// seule").
///
/// Heuristique volontairement simple (longueur + variete de categories de
/// caracteres), sans dependance externe : ce mot de passe protege uniquement contre un
/// tiers ayant deja acces a l'app pendant une session macOS deverrouillee (voir
/// `LockService`), pas contre une attaque hors ligne outillee -- un calcul de
/// robustesse plus sophistique (zxcvbn et assimiles) serait disproportionne pour cette
/// menace.
public enum PasswordStrength: Sendable, Equatable, CaseIterable {
    case weak
    case medium
    case strong

    /// Evalue la robustesse de `password` : longueur ET diversite de categories de
    /// caracteres (minuscule/majuscule confondues en "lettre", chiffre, symbole)
    /// comptent toutes les deux -- un mot de passe long mais d'une seule categorie
    /// (ex: "aaaaaaaaaa") ne doit pas se faire passer pour robuste.
    public static func evaluate(_ password: String) -> PasswordStrength {
        let length = password.count
        guard length > 0 else { return .weak }

        var categoryCount = 0
        if password.contains(where: \.isLetter) { categoryCount += 1 }
        if password.contains(where: \.isNumber) { categoryCount += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber }) { categoryCount += 1 }

        if length >= 12, categoryCount >= 2 { return .strong }
        if length >= 8, categoryCount >= 2 { return .medium }
        if length >= 10 { return .medium }
        return .weak
    }

    /// Fraction remplie de la jauge (design : "70%" pour "Robuste").
    var fillFraction: Double {
        switch self {
        case .weak: 0.34
        case .medium: 0.66
        case .strong: 1
        }
    }

    var fillColor: Color {
        switch self {
        case .weak: SlateColor.semanticErrorFill
        case .medium: SlateColor.semanticWarning
        case .strong: SlateColor.semanticSuccess
        }
    }

    /// Mot accompagnant la jauge -- jamais la couleur seule (design P3, artboard C).
    var localizedLabel: String {
        switch self {
        case .weak: String(localized: "lock.setPassword.strength.weak", bundle: .module)
        case .medium: String(localized: "lock.setPassword.strength.medium", bundle: .module)
        case .strong: String(localized: "lock.setPassword.strength.strong", bundle: .module)
        }
    }
}

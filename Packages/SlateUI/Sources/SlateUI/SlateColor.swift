import SwiftUI

/// Tokens de couleur semantiques de Slate.
///
/// Phase 1 : bases uniquement sur les couleurs systeme macOS (`Color(nsColor:)`,
/// couleurs semantiques SwiftUI). Les valeurs hexadecimales precises de
/// `design/tokens.md` (§1 a §8) arrivent en Phase 13 avec le vrai theme ; ce fichier
/// ne doit pas les anticiper. Les NOMS ci-dessous sont deliberement alignes sur ceux
/// de `design/tokens.md` pour que le remplacement en Phase 13 se fasse token par
/// token, sans toucher les vues appelantes.
public enum SlateColor {
    // MARK: - Fonds & surfaces (design/tokens.md §1)

    /// Fond de fenetre. Equivalent `bg.window`.
    public static let bgWindow = Color(nsColor: .windowBackgroundColor)

    /// Fond de colonne liste. Equivalent `bg.list`.
    public static let bgList = Color(nsColor: .controlBackgroundColor)

    /// Fond de zone d'edition. Equivalent `bg.editor`.
    public static let bgEditor = Color(nsColor: .textBackgroundColor)

    /// Surface primaire (cartes, panneaux, popovers). Equivalent `surface.primary`.
    public static let surfacePrimary = Color(nsColor: .controlBackgroundColor)

    /// Surface secondaire (champs, zones secondaires). Equivalent `surface.secondary`.
    public static let surfaceSecondary = Color(nsColor: .underPageBackgroundColor)

    // MARK: - Texte (design/tokens.md §2)

    /// Texte principal. Equivalent `text.primary`.
    public static let textPrimary = Color.primary

    /// Texte secondaire (metadonnees). Equivalent `text.secondary`.
    public static let textSecondary = Color.secondary

    /// Texte discret. Equivalent `text.tertiary`.
    public static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // MARK: - Accent (design/tokens.md §3)

    /// Accent principal. Equivalent `accent.default`. Personnalisable par
    /// l'utilisateur a terme (design/tokens.md §7) ; pour l'instant l'accent
    /// systeme macOS.
    public static let accentDefault = Color.accentColor

    // MARK: - Separateurs & bordures (design/tokens.md §5)

    /// Separateur standard. Equivalent `separator`.
    public static let separator = Color(nsColor: .separatorColor)
}

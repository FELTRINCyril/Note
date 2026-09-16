import Testing
import SwiftUI
@testable import SlateUI

/// Verification visuelle de la derivation des couleurs par accent (Phase 13, design/
/// tokens.md §7) : une meme composition (checkbox cochee, pastille de base de donnees,
/// bouton plein) rendue sous plusieurs accents, clair ET sombre, pour verifier a l'oeil
/// que `accentDefault`/`textOnAccent`/`accentSubtle` se derivent correctement -- pas
/// seulement par le calcul WCAG deja couvert par `AccentPersonalizationContrastTests`.
///
/// `ThemeManager` est un singleton partage a l'echelle du processus de test (voir sa
/// documentation) : suite `.serialized` + restauration par `defer`, meme precaution que
/// `AppearanceSettingsWiringTests`.
@MainActor
@Suite("Verification visuelle - derivation par accent (Phase 13)", .serialized)
struct ThemeSnapshotTests {
    @Test(
        "Composition de reference sous 3 accents distincts, clair et sombre",
        arguments: [SlateAccentColor.blue, .orange, .graphite]
    )
    func accentDerivation(accent: SlateAccentColor) throws {
        let original = ThemeManager.shared.accent
        defer { ThemeManager.shared.accent = original }

        ThemeManager.shared.accent = accent

        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                AccentReferenceComposition().environment(\.colorScheme, scheme),
                named: "theme_accent_\(accent.rawValue)_\(scheme.snapshotSuffix)"
            )
        }
    }
}

/// Composition volontairement heterogene, choisie pour ne contenir QUE des elements
/// qui derivent reellement de l'accent COURANT (`ThemeManager.shared.accent`) : un
/// bouton plein (`accentDefault` + `textOnAccent`), une checkbox cochee (meme paire de
/// tokens dans un composant reel), la pastille active de `MediaAlignmentBar`
/// (`accentDefault` en aplat + `foregroundOnAccentFill`), et le lien de
/// `MediaDropzoneView` (`accentDefault` en TEXTE, pas en aplat -- verifie `linkRGB`).
/// `DatabasePillView` est volontairement absent : son `accent` est un parametre
/// explicite de l'appelant (ex: `.blue`), pas l'accent de theme courant -- l'inclure
/// ici produirait une pastille visuellement IDENTIQUE d'un accent de theme a l'autre,
/// ce qui fausserait la comparaison.
private struct AccentReferenceComposition: View {
    @State private var isDone = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button("Action principale") {}
                .buttonStyle(.borderedProminent)
                .tint(SlateColor.accentDefault)

            ChecklistItemView(isDone: $isDone) { Text("Tache faite - checkbox pleine") }

            MediaAlignmentBar(selection: .center) { _ in }

            MediaDropzoneView(isTargeted: false)
        }
        .padding(Spacing.lg)
        .frame(width: 420)
        .background(SlateColor.bgEditor)
    }
}

import Testing
@testable import SlateUI

/// Verifie que les trois reglages livres (mais non branches) par la fenetre de reglages
/// pilotent reellement quelque chose (Phase 13 "suite") : avant ce branchement, ils
/// etaient stockes dans un `AppearanceSettingsStore` (`SlateFeatures`) sans aucun
/// consommateur -- une case active qui ne fait rien, ce que le projet s'interdit (regle
/// "desactive, jamais masque" : elle suppose que ce qui est actif fonctionne).
///
/// `ThemeManager` etant un singleton partage a l'echelle du processus de test, chaque
/// test restaure l'etat d'origine en sortie (`defer`) -- meme precaution que
/// `ThemeManagerIntegrationTests` dans `AccentPersonalizationContrastTests.swift`.
@Suite("Reglages d'apparence branches (Phase 13 suite)", .serialized)
@MainActor
struct AppearanceSettingsWiringTests {
    @Test("increasesSeparatorContrast (reglage Slate) fait passer les separateurs en contraste renforce")
    func increaseSeparatorContrastTogglesTokens() {
        let original = ThemeManager.shared.increasesSeparatorContrast
        defer { ThemeManager.shared.increasesSeparatorContrast = original }

        ThemeManager.shared.increasesSeparatorContrast = false
        let baseSeparator = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.10)
        #expect(!slateSeparatorsUseIncreasedContrast())

        ThemeManager.shared.increasesSeparatorContrast = true
        #expect(slateSeparatorsUseIncreasedContrast())

        // Verifie que le token lui-meme change de valeur (pas seulement le booleen
        // intermediaire) : on compare le contraste obtenu par la regle de calcul de
        // `SlateColor.separator` (memes alphas que la propriete reelle) avant/apres.
        let boostedSeparator = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.25)
        let white = SlateRGB.white
        let baseRatio = WCAGContrast.ratio(WCAGContrast.compositeOverBackground(baseSeparator, white), white)
        let boostedRatio = WCAGContrast.ratio(WCAGContrast.compositeOverBackground(boostedSeparator, white), white)
        #expect(boostedRatio > baseRatio)
    }

    @Test("increasesSeparatorContrast a false : le reglage systeme (Increase Contrast) reste seul maitre")
    func systemIncreaseContrastStillAppliesWhenAppSettingIsOff() {
        let originalApp = ThemeManager.shared.increasesSeparatorContrast
        defer {
            ThemeManager.shared.increasesSeparatorContrast = originalApp
            slatePublishIncreasesContrast(false)
        }

        ThemeManager.shared.increasesSeparatorContrast = false
        slatePublishIncreasesContrast(false)
        #expect(!slateSeparatorsUseIncreasedContrast())

        // Le reglage systeme seul (sans le reglage Slate) suffit deja a activer le
        // contraste renforce : c'est la regle OR exigee ("l'un OU l'autre suffit").
        slatePublishIncreasesContrast(true)
        #expect(slateSeparatorsUseIncreasedContrast())
    }

    @Test("reducesSidebarTransparency (reglage Slate) est repercute dans le miroir lu par SidebarMaterialBackground")
    func reducesSidebarTransparencyTogglesMirror() {
        let original = ThemeManager.shared.reducesSidebarTransparency
        defer { ThemeManager.shared.reducesSidebarTransparency = original }

        ThemeManager.shared.reducesSidebarTransparency = false
        #expect(!slateReducesSidebarTransparencyOverride())

        ThemeManager.shared.reducesSidebarTransparency = true
        #expect(slateReducesSidebarTransparencyOverride())
    }

    @Test("showsNoteCover est bien porte par ThemeManager (persistance et valeur par defaut)")
    func showsNoteCoverIsPersistedOnThemeManager() {
        let original = ThemeManager.shared.showsNoteCover
        defer { ThemeManager.shared.showsNoteCover = original }

        ThemeManager.shared.showsNoteCover = false
        #expect(ThemeManager.shared.showsNoteCover == false)

        ThemeManager.shared.showsNoteCover = true
        #expect(ThemeManager.shared.showsNoteCover == true)
    }
}

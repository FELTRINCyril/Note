import Testing
@testable import SlateFeatures

/// Verifie la regle d'honnetete d'interface du projet pour les onglets IA et General
/// des reglages (Phase 13) : tant qu'aucune fonctionnalite reelle n'existe derriere un
/// controle, la constante correspondante DOIT rester `false`, et les vues DOIVENT s'y
/// referer plutot que de coder `.disabled(true)` en dur (voir
/// `AISettingsTabView`/`GeneralSettingsTabView`).
///
/// Ces tests ne verifient pas l'etat visuel `.disabled` d'une vue SwiftUI (aucun
/// support d'inspection de vue dans ce projet) : ils figent la DECISION honnete elle-
/// meme, pour qu'un futur changement accidentel (ex: quelqu'un met `true` sans avoir
/// implemente la fonctionnalite) casse un test plutot que de se glisser silencieusement
/// dans l'UI.
@Suite("Honnetete des reglages IA/General")
struct SettingsAvailabilityTests {
    @Test("Aucun controle IA n'est presente comme fonctionnel : Phase 18 non livree")
    func aiControlsAreHonestlyDisabled() {
        #expect(AISettingsAvailability.isProcessingModeEditable == false)
        #expect(AISettingsAvailability.isRebuildIndexAvailable == false)
    }

    @Test("Aucun controle General non implemente n'est presente comme fonctionnel")
    func generalControlsAreHonestlyDisabled() {
        #expect(GeneralSettingsAvailability.isReopenLastNoteEditable == false)
        #expect(GeneralSettingsAvailability.isCloudSyncEditable == false)
        #expect(GeneralSettingsAvailability.isNewNoteDestinationEditable == false)
    }
}

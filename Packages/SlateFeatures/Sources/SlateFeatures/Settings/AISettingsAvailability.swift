import Foundation

/// Etat de disponibilite REEL des reglages de l'onglet "IA" (design P4, artboard A).
///
/// L'assistant IA est la Phase 18 : rien n'existe encore derriere ces controles
/// aujourd'hui (aucun moteur de traitement, aucun index de recherche). Regle
/// d'honnetete d'interface du projet -- "jamais donner l'illusion de fonctionner" --
/// donc chaque controle correspondant reste desactive tant que ces constantes valent
/// `false`. Extrait en constantes plutot que des `.disabled(true)` eparpilles dans la
/// vue pour rester verifiable par un test (`AISettingsAvailabilityTests`) sans
/// inspection de vue SwiftUI.
enum AISettingsAvailability {
    /// Le choix du mode de traitement (sur l'appareil / distant) n'est pas encore
    /// branche a un moteur reel.
    static let isProcessingModeEditable = false

    /// Aucun index de recherche IA n'existe encore : "Reconstruire" ne doit rien
    /// pretendre declencher.
    static let isRebuildIndexAvailable = false
}

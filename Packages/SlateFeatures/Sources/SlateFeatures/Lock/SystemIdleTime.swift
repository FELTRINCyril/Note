import CoreGraphics
import Foundation

/// Temps ecoule (en secondes) depuis la derniere activite clavier/souris/trackpad
/// SYSTEME, via CoreGraphics -- utilise par `AutoRelockCoordinator` pour le
/// reverrouillage automatique par inactivite (`docs/12_verrouillage.md`).
///
/// Choix deliberement PAS un moniteur d'evenements global (`NSEvent.addGlobalMonitorForEvents`) :
/// ce dernier necessite l'autorisation Accessibilite sur macOS dans certains contextes
/// et complique les tests (etat mutable partage). `CGEventSource.secondsSinceLastEventType`
/// est l'API publique dediee a cette mesure (la meme que celle qu'utilise l'economiseur
/// d'ecran systeme) : aucune permission particuliere requise, valeur lue a la demande.
enum SystemIdleTime {
    /// Secondes ecoulees depuis la derniere activite systeme (`.combinedSessionState`
    /// couvre clavier, souris ET evenements de defilement/trackpad).
    static func seconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
    }
}

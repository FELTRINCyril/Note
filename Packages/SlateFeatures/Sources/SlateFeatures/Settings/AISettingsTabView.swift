import SwiftUI
import SlateUI

/// Contenu de l'onglet "IA" des reglages (design P4, artboard A).
///
/// **Honnetete d'interface, a lire avant de toucher ce fichier** : l'assistant IA est
/// la Phase 18. Aucun moteur de traitement ni index de recherche n'existe -- tous les
/// controles sont donc desactives via `AISettingsAvailability` (voir sa
/// documentation), et le decompte de notes indexees N'EST PAS invente : la maquette
/// affiche "1 284 notes indexees" a titre d'exemple, mais afficher un chiffre fictif
/// serait un mensonge d'interface. Ce texte est remplace par une mention explicite
/// d'indisponibilite.
struct AISettingsTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SettingsRow(
                label: String(localized: "settings.ai.processing.label", bundle: .module),
                caption: String(localized: "settings.ai.processing.caption", bundle: .module)
            ) {
                Picker(
                    String(localized: "settings.ai.processing.label", bundle: .module),
                    selection: .constant(ProcessingMode.onDevice)
                ) {
                    Text(String(localized: "settings.ai.processing.onDevice", bundle: .module))
                        .tag(ProcessingMode.onDevice)
                    Text(String(localized: "settings.ai.processing.remote", bundle: .module))
                        .tag(ProcessingMode.remote)
                }
                .labelsHidden()
                .disabled(!AISettingsAvailability.isProcessingModeEditable)
            }

            SettingsRow(
                label: String(localized: "settings.ai.searchIndex.label", bundle: .module),
                caption: String(localized: "settings.ai.searchIndex.unavailable", bundle: .module)
            ) {
                Button(String(localized: "settings.ai.searchIndex.rebuild", bundle: .module)) {}
                    .disabled(!AISettingsAvailability.isRebuildIndexAvailable)
            }
        }
        .padding(Spacing.lg)
    }

    private enum ProcessingMode {
        case onDevice
        case remote
    }
}

#Preview("AISettingsTabView") {
    AISettingsTabView()
        .frame(width: 620)
}

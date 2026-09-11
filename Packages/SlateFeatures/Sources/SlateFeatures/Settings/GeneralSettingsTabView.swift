import SwiftUI
import SlateModel
import SlateUI

/// Contenu de l'onglet "General" des reglages (design P4, artboard A).
///
/// Meme regle d'honnetete d'interface que `AISettingsTabView` : voir
/// `GeneralSettingsAvailability`. Le toggle iCloud reprend le motif deja utilise par
/// `SyncStatusView` (barre d'outils, Phase 3) -- annoncer un FAIT verifiable a la
/// compilation (`SlateContainer.isCloudKitEnabled`), jamais une pretention de reglage
/// utilisateur qui n'existe pas.
struct GeneralSettingsTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SettingsRow(label: String(localized: "settings.general.startup.label", bundle: .module)) {
                Toggle(
                    String(localized: "settings.general.startup.reopenLastNote", bundle: .module),
                    isOn: .constant(false)
                )
                .toggleStyle(.checkbox)
                .disabled(!GeneralSettingsAvailability.isReopenLastNoteEditable)
            }

            SettingsRow(
                label: nil,
                caption: String(localized: "settings.general.cloudSync.caption", bundle: .module)
            ) {
                Toggle(
                    String(localized: "settings.general.cloudSync.label", bundle: .module),
                    isOn: .constant(SlateContainer.isCloudKitEnabled)
                )
                .toggleStyle(.checkbox)
                .disabled(!GeneralSettingsAvailability.isCloudSyncEditable)
            }

            SettingsRow(
                label: String(localized: "settings.general.newNote.label", bundle: .module),
                caption: String(localized: "settings.general.newNote.caption", bundle: .module)
            ) {
                Picker(
                    String(localized: "settings.general.newNote.label", bundle: .module),
                    selection: .constant(0)
                ) {
                    Text(String(localized: "settings.general.newNote.currentFolder", bundle: .module)).tag(0)
                }
                .labelsHidden()
                .disabled(!GeneralSettingsAvailability.isNewNoteDestinationEditable)
            }
        }
        .padding(Spacing.lg)
    }
}

#Preview("GeneralSettingsTabView") {
    GeneralSettingsTabView()
        .frame(width: 620)
}

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
///
/// ## Premier controle REELLEMENT actif de cet onglet (Phase 15)
/// "Convertir le markdown colle en blocs" est le premier reglage de cet onglet qui n'est
/// PAS gouverne par `GeneralSettingsAvailability` (donc jamais `.disabled`) : il pilote
/// veritablement `EditorPreferences.shared.convertsMarkdownOnPaste` (`SlateUI`), lu par
/// `RichTextEditingTextView.paste(_:)` (`SlateEditor`) a chaque Cmd+V. Meme motif de
/// persistance que `AppearanceSettingsTabView`/`ThemeManager` : un `@Observable` partage
/// et `@Bindable`, pas un `.constant(...)`.
struct GeneralSettingsTabView: View {
    @Bindable private var editorPreferences = EditorPreferences.shared

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

            SettingsRow(
                label: nil,
                caption: String(localized: "settings.general.markdownPaste.caption", bundle: .module)
            ) {
                Toggle(
                    String(localized: "settings.general.markdownPaste.label", bundle: .module),
                    isOn: $editorPreferences.convertsMarkdownOnPaste
                )
                .toggleStyle(.checkbox)
            }
        }
        .padding(Spacing.lg)
    }
}

#Preview("GeneralSettingsTabView") {
    GeneralSettingsTabView()
        .frame(width: 620)
}

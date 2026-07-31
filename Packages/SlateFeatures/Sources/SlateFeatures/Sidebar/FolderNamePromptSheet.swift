import SwiftUI
import SlateModel
import SlateUI

/// Contexte d'affichage de `FolderNamePromptSheet` : soit la creation d'un nouveau
/// sous-dossier (ou dossier racine si `parent` est `nil`), soit le renommage d'un
/// dossier existant. Un seul type de feuille pour les deux cas plutot que d'en
/// dupliquer une quasi identique, comme demande ("Renommage en place ou par boite de
/// dialogue, choisis le plus sobre" - la boite de dialogue est retenue ici parce
/// qu'elle sert aussi, sans duplication, a la creation).
struct FolderNamePromptContext: Identifiable {
    enum Mode {
        case newSubfolder(parent: Folder?, space: Space)
        case rename(folder: Folder)
    }

    let id = UUID()
    let mode: Mode
}

/// Boite de dialogue de saisie d'un nom de dossier (creation ou renommage).
struct FolderNamePromptSheet: View {
    let context: FolderNamePromptContext
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(context: FolderNamePromptContext, onSubmit: @escaping (String) -> Void) {
        self.context = context
        self.onSubmit = onSubmit
        switch context.mode {
        case .newSubfolder:
            _name = State(initialValue: "")
        case .rename(let folder):
            _name = State(initialValue: folder.name)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .slateFont(SlateFont.bodyEmphasis)
                .foregroundStyle(SlateColor.textPrimary)
            TextField(String(localized: "sidebar.folder.namePrompt.field", bundle: .module), text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            HStack {
                Spacer()
                Button(String(localized: "action.cancel", bundle: .module)) {
                    dismiss()
                }
                Button(String(localized: "action.confirm", bundle: .module), action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(Spacing.lg)
        .frame(minWidth: 320)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        switch context.mode {
        case .newSubfolder:
            String(localized: "sidebar.folder.namePrompt.newTitle", bundle: .module)
        case .rename:
            String(localized: "sidebar.folder.namePrompt.renameTitle", bundle: .module)
        }
    }

    private func submit() {
        guard !trimmedName.isEmpty else { return }
        onSubmit(trimmedName)
        dismiss()
    }
}

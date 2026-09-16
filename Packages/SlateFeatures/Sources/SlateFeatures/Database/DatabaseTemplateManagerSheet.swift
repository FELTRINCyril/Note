import SlateModel
import SlateUI
import SwiftUI

/// Liste des templates d'une base ("Gerer les templates...", 17.6) : editer/appliquer/
/// supprimer un template existant, ou en creer un nouveau (`DatabaseTemplateEditorSheet`).
struct DatabaseTemplateManagerSheet: View {
    @Bindable var viewModel: DatabaseViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editedTemplate: DatabaseTemplate?
    @State private var isCreatingTemplate = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(localized: "database.template.manage", bundle: .module))
                .slateFont(SlateFont.h3)
                .foregroundStyle(SlateColor.textPrimary)

            if viewModel.templates.isEmpty {
                Text(String(localized: "database.template.emptyState", bundle: .module))
                    .slateFont(SlateFont.body)
                    .foregroundStyle(SlateColor.textSecondary)
            } else {
                ForEach(viewModel.templates) { template in
                    HStack {
                        Text(template.name)
                            .slateFont(SlateFont.label)
                            .foregroundStyle(SlateColor.textPrimary)
                        Spacer(minLength: Spacing.sm)
                        Button(String(localized: "action.edit", bundle: .module)) { editedTemplate = template }
                            .buttonStyle(.plain)
                            .foregroundStyle(SlateColor.textLink)
                        Button(role: .destructive) {
                            viewModel.deleteTemplate(template.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            DatabasePrimaryButton(String(localized: "database.template.new", bundle: .module)) {
                isCreatingTemplate = true
            }

            Spacer(minLength: 0)

            DatabaseSecondaryButton(String(localized: "action.done", bundle: .module)) { dismiss() }
        }
        .padding(Spacing.lg)
        .frame(width: 320, height: 360)
        .sheet(isPresented: $isCreatingTemplate) {
            DatabaseTemplateEditorSheet(viewModel: viewModel, template: nil) { isCreatingTemplate = false }
        }
        .sheet(item: $editedTemplate) { template in
            DatabaseTemplateEditorSheet(viewModel: viewModel, template: template) { editedTemplate = nil }
        }
    }
}

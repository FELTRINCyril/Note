import SlateModel
import SlateUI
import SwiftUI

/// Assemble les 5 vues d'une `Database` (17.3/17.5) autour d'une barre commune : titre,
/// bascule de vue (`DatabaseViewSwitcher`), bouton filtres/tris/groupement, ajout de
/// champ, ajout de ligne (avec templates). C'est CE composant que consomment aussi bien
/// une base pleine page (`DatabaseFullPageView`) que le rendu inline de l'editeur
/// (`DatabaseInlineHostFactory`, `SlateEditor`).
///
/// Critere d'acceptation explicite (`docs/17_base_de_donnees.md`) : "basculer entre les
/// 5 vues sur les MEMES donnees" - garanti ici en construisant un SEUL
/// `DatabaseViewModel` partage par toutes les vues (`viewModel.viewKind` pilote
/// uniquement QUEL contenu est affiche, jamais quelles donnees).
public struct DatabaseHostView: View {
    @Bindable var viewModel: DatabaseViewModel
    private let showsHeader: Bool

    @State private var isFilterMenuPresented = false
    @State private var editedFieldID: UUID?
    @State private var isAddingField = false
    @State private var isTemplateManagerPresented = false

    public init(viewModel: DatabaseViewModel, showsHeader: Bool = true) {
        self.viewModel = viewModel
        self.showsHeader = showsHeader
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsHeader {
                header
            }
            toolbar
            Divider()
            content
        }
        .sheet(item: fieldEditorItem) { target in
            DatabaseFieldEditorSheet(viewModel: viewModel, fieldID: target.fieldID, onDismiss: dismissFieldEditor)
        }
        .sheet(isPresented: $isTemplateManagerPresented) {
            DatabaseTemplateManagerSheet(viewModel: viewModel)
        }
    }

    private var header: some View {
        let trimmedName = viewModel.database.name
        let title = trimmedName.isEmpty ? String(localized: "database.untitled", bundle: .module) : trimmedName
        return HStack {
            Text(title)
                .slateFont(SlateFont.h3)
                .foregroundStyle(SlateColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
    }

    private var toolbar: some View {
        HStack(spacing: Spacing.sm) {
            DatabaseViewSwitcher(selection: viewModel.viewKind, titles: viewTitles) { viewModel.viewKind = $0 }
            Spacer(minLength: Spacing.sm)
            Button {
                isFilterMenuPresented = true
            } label: {
                Label(
                    String(localized: "database.toolbar.filters", bundle: .module),
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(activeFilterCount > 0 ? SlateColor.textLink : SlateColor.textSecondary)
            .popover(isPresented: $isFilterMenuPresented) {
                DatabaseFilterSortGroupMenu(viewModel: viewModel)
            }
            if viewModel.viewKind == .grid {
                DatabaseTemplateMenu(viewModel: viewModel) { isTemplateManagerPresented = true }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewKind {
        case .grid:
            DatabaseGridView(
                viewModel: viewModel,
                onEditField: { editedFieldID = $0 },
                onAddField: { isAddingField = true }
            )
        case .kanban:
            DatabaseKanbanView(viewModel: viewModel)
        case .calendar:
            DatabaseCalendarView(viewModel: viewModel)
        case .gallery:
            DatabaseGalleryView(viewModel: viewModel)
        case .list:
            DatabaseListSimpleView(viewModel: viewModel)
        }
    }

    private var viewTitles: [SlateDatabaseViewKind: String] {
        [
            .grid: String(localized: "database.view.grid", bundle: .module),
            .kanban: String(localized: "database.view.kanban", bundle: .module),
            .calendar: String(localized: "database.view.calendar", bundle: .module),
            .gallery: String(localized: "database.view.gallery", bundle: .module),
            .list: String(localized: "database.view.list", bundle: .module)
        ]
    }

    private var activeFilterCount: Int { viewModel.filter.conditions.count }

    /// `sheet(item:)` a besoin d'un `Identifiable` : `isAddingField`/`editedFieldID`
    /// partagent la meme feuille (`DatabaseFieldEditorSheet`, `fieldID == nil` = creation)
    /// via ce wrapper, plutot que deux presentations concurrentes qui pourraient se
    /// chevaucher.
    private var fieldEditorItem: Binding<DatabaseFieldEditorTarget?> {
        Binding(
            get: {
                if isAddingField { return DatabaseFieldEditorTarget(fieldID: nil) }
                if let editedFieldID { return DatabaseFieldEditorTarget(fieldID: editedFieldID) }
                return nil
            },
            set: { newValue in
                isAddingField = false
                editedFieldID = newValue?.fieldID
            }
        )
    }

    private func dismissFieldEditor() {
        isAddingField = false
        editedFieldID = nil
    }
}

/// Cible d'edition de champ (creation ou edition), voir `DatabaseHostView.fieldEditorItem`.
private struct DatabaseFieldEditorTarget: Identifiable {
    let fieldID: UUID?
    var id: String { fieldID?.uuidString ?? "new" }
}

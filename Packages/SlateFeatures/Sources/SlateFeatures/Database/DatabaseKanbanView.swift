import SlateModel
import SlateUI
import SwiftUI

/// Vue Kanban (17.5) : colonnes = groupes du champ `groupFieldID` (`DatabaseGroup`,
/// `DatabaseQueryEngine.group`), cartes deplacables entre colonnes. Un glisser-depose
/// termine met a jour la valeur du champ de regroupement de la ligne deplacee
/// (`DatabaseViewModel.moveRow(_:toGroup:fieldID:)`) - critere d'acceptation explicite de
/// `docs/17_base_de_donnees.md`.
///
/// N'accepte que les champs `.singleSelect` comme regroupement : un `.multiSelect` fait
/// apparaitre une meme ligne dans plusieurs colonnes (voir `DatabaseGroup` de
/// `SlateModel`), et deplacer une carte entre deux colonnes d'un tel champ n'aurait pas
/// de sens univoque (faudrait-il retirer l'option de la colonne source ? en ajouter une
/// seule ? les deux lectures sont defendables, aucune n'est evidente) - ecarte plutot que
/// devine, en cherchant le premier champ `.singleSelect` disponible si `groupFieldID`
/// vise un autre type.
struct DatabaseKanbanView: View {
    @Bindable var viewModel: DatabaseViewModel

    var body: some View {
        Group {
            if let fieldID = kanbanFieldID {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        ForEach(groups(for: fieldID)) { group in
                            column(group, fieldID: fieldID)
                        }
                    }
                    .padding(Spacing.lg)
                }
            } else {
                DatabaseKanbanEmptyStateView()
            }
        }
        .background(SlateColor.bgEditor)
    }

    private var kanbanFieldID: UUID? {
        if let groupFieldID = viewModel.groupFieldID,
           viewModel.snapshot.field(withID: groupFieldID)?.type == .singleSelect {
            return groupFieldID
        }
        return viewModel.snapshot.fields.first { $0.type == .singleSelect }?.id
    }

    private func groups(for fieldID: UUID) -> [KanbanGroup] {
        let engineGroups = DatabaseQueryEngine.group(
            viewModel.visibleRows,
            by: fieldID,
            fields: viewModel.snapshot.fields,
            relatedDatabases: [:]
        )
        let options = viewModel.snapshot.field(withID: fieldID)?.configuration.selectOptions ?? []
        return engineGroups.map { group in
            KanbanGroup(key: group.key, rows: group.rows, title: title(for: group.key, options: options))
        }
    }

    private func title(for key: DatabaseGroupKey, options: [DatabaseSelectOption]) -> KanbanColumnTitle {
        guard case .option(let optionID) = key, let option = options.first(where: { $0.id == optionID }) else {
            let noValue = String(localized: "database.kanban.noValue", bundle: .module)
            return KanbanColumnTitle(title: noValue, optionID: nil, style: SlateDatabasePillStyle(accent: nil))
        }
        let style = DatabaseCellFormatting.pillStyle(for: option)
        return KanbanColumnTitle(title: option.label, optionID: option.id, style: style)
    }

    private func column(_ group: KanbanGroup, fieldID: UUID) -> some View {
        DatabaseKanbanColumnView(title: group.title.title, count: group.rows.count, pillStyle: group.title.style) {
            VStack(spacing: Spacing.sm) {
                ForEach(group.rows) { row in
                    DatabaseKanbanCardView(title: cardTitle(row), tags: cardTags(row)) {
                        EmptyView()
                    }
                    .draggable(row.id.uuidString)
                }
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let rowIDString = items.first, let rowID = UUID(uuidString: rowIDString) else { return false }
            viewModel.moveRow(rowID, toGroup: group.title.optionID, fieldID: fieldID)
            return true
        }
    }

    private func cardTitle(_ row: DatabaseRowSnapshot) -> String {
        guard let firstTextField = viewModel.snapshot.fields.first(where: { $0.type == .text }) else {
            return String(localized: "database.kanban.untitledCard", bundle: .module)
        }
        return DatabaseCellFormatting.displayText(row.values[firstTextField.id], field: firstTextField)
            ?? String(localized: "database.kanban.untitledCard", bundle: .module)
    }

    private func cardTags(_ row: DatabaseRowSnapshot) -> [(title: String, style: SlateDatabasePillStyle)] {
        guard let multiSelectField = viewModel.snapshot.fields.first(where: { $0.type == .multiSelect }) else {
            return []
        }
        return DatabaseCellFormatting.tags(for: row.values[multiSelectField.id], field: multiSelectField)
    }

    private struct KanbanGroup: Identifiable {
        let key: DatabaseGroupKey
        let rows: [DatabaseRowSnapshot]
        let title: KanbanColumnTitle

        var id: DatabaseGroupKey { key }
    }
}

/// Titre resolu d'une colonne Kanban : libelle affiche, identifiant de l'option
/// (`nil` pour la colonne "Sans valeur", cible du glisser-depose vers "aucune valeur"),
/// style de pastille. Struct dediee plutot qu'un tuple a 3 membres (limite SwiftLint
/// `large_tuple`).
private struct KanbanColumnTitle {
    let title: String
    let optionID: UUID?
    let style: SlateDatabasePillStyle
}

private struct DatabaseKanbanEmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "rectangle.split.3x1")
                .slateIconFont(28, relativeTo: .largeTitle)
                .foregroundStyle(SlateColor.textTertiary)
            Text(String(localized: "database.kanban.emptyState", bundle: .module))
                .slateFont(SlateFont.body)
                .foregroundStyle(SlateColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.lg)
    }
}

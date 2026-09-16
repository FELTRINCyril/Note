import SwiftUI

/// Menu de filtres / tris / regroupement (design/tokens.md §18, artboard D, panneau
/// sombre). Composants de PRESENTATION purs et volontairement GENERIQUES : ce menu ne
/// connait ni les champs ni les operateurs reels -- l'appelant compose chaque ligne a
/// partir de `DatabaseFilterChip` (un segment "Statut" / "n'est pas" / "Livre"...).

/// Titre de section en majuscules (design : "FILTRES" / "TRIS" / "GROUPEMENT").
public struct DatabaseMenuSectionLabel: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .slateFont(SlateFont.sidebarSectionHeader)
            .foregroundStyle(SlateColor.textSecondary)
    }
}

/// Un segment d'une ligne de condition (ex: le nom d'un champ, un operateur, une
/// valeur). Bouton generique : l'appelant decide de ce que tape dessus declenche
/// (ouvrir un picker de champ, d'operateur...).
public struct DatabaseFilterChip: View {
    private let text: String
    private let fillsRemainingWidth: Bool
    private let action: () -> Void

    public init(_ text: String, fillsRemainingWidth: Bool = false, action: @escaping () -> Void = {}) {
        self.text = text
        self.fillsRemainingWidth = fillsRemainingWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(text)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, Spacing.sm)
                .frame(height: 24)
                .frame(maxWidth: fillsRemainingWidth ? .infinity : nil, alignment: .leading)
                .background(SlateColor.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                        .strokeBorder(SlateColor.borderDefault)
                )
                .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall))
        }
        .buttonStyle(.plain)
    }
}

/// Une ligne de condition complete (chips + bouton de suppression). `chips` est libre :
/// l'appelant y place autant de `DatabaseFilterChip` que necessaire (champ, operateur,
/// valeur).
public struct DatabaseConditionRow<Chips: View>: View {
    private let chips: Chips
    private let onRemove: () -> Void

    public init(@ViewBuilder chips: () -> Chips, onRemove: @escaping () -> Void = {}) {
        self.chips = chips()
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            chips
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .slateIconFont(11, weight: .semibold, relativeTo: .caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SlateColor.textSecondary)
            .accessibilityLabel(SlateUIStrings.databaseRemoveConditionLabel)
        }
    }
}

/// Les deux actions d'ajout d'une section Filtres (design : "+ Filtre" / "+ Groupe de
/// conditions", en `text.link`).
public struct DatabaseAddFilterActionsRow: View {
    private let onAddFilter: () -> Void
    private let onAddGroup: () -> Void

    public init(onAddFilter: @escaping () -> Void, onAddGroup: @escaping () -> Void) {
        self.onAddFilter = onAddFilter
        self.onAddGroup = onAddGroup
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            Button(SlateUIStrings.databaseAddFilterLabel, action: onAddFilter)
            Button(SlateUIStrings.databaseAddFilterGroupLabel, action: onAddGroup)
        }
        .buttonStyle(.plain)
        .slateFont(SlateFont.label)
        .foregroundStyle(SlateColor.textLink)
    }
}

/// Case a cocher texte + libelle (ex: "Groupes vides", "Afficher dans le Kanban",
/// artboards A/D). Reutilise le dessin de `DatabaseCheckboxToggle` (meme geometrie que
/// la case a cocher de cellule) avec un libelle accole.
public struct DatabaseLabeledCheckbox: View {
    @Binding private var isChecked: Bool
    private let title: String

    public init(_ title: String, isChecked: Binding<Bool>) {
        self.title = title
        self._isChecked = isChecked
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            DatabaseCheckboxToggle(isChecked: $isChecked)
            Text(title)
                .slateFont(SlateFont.label)
                .foregroundStyle(SlateColor.textPrimary)
        }
    }
}

#Preview("DatabaseFilterMenuViews - clair") {
    DatabaseFilterMenuPreview()
        .environment(\.colorScheme, .light)
}

#Preview("DatabaseFilterMenuViews - sombre") {
    DatabaseFilterMenuPreview()
        .environment(\.colorScheme, .dark)
}

private struct DatabaseFilterMenuPreview: View {
    @State private var showsEmptyGroups = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            DatabaseMenuSectionLabel("Filtres")
            DatabaseConditionRow {
                DatabaseFilterChip("Statut")
                DatabaseFilterChip("n'est pas")
                DatabaseFilterChip("Livre", fillsRemainingWidth: true)
            }
            DatabaseAddFilterActionsRow(onAddFilter: {}, onAddGroup: {})
            Divider()
            DatabaseMenuSectionLabel("Groupement")
            DatabaseLabeledCheckbox("Groupes vides", isChecked: $showsEmptyGroups)
        }
        .padding(Spacing.md)
        .frame(width: 320)
        .background(SlateColor.surfacePrimary)
    }
}

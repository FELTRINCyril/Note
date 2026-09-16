import SwiftUI

/// Cellules de la vue Grille, une par type de champ (design/tokens.md §18, artboard A).
/// Composants de PRESENTATION purs : la valeur formattee est fournie par l'appelant
/// (`SlateFeatures`), qui seul connait le champ reel et son type.

/// Enveloppe commune d'une cellule de grille : padding, filet de bordure a droite,
/// alignement vertical. Reutilise `table.border`/`table.rowStripe` (Phase 8) tels quels
/// (design/tokens.md §18 : `db.grid.cellBorder` = `table.border`).
public struct DatabaseGridCell<Content: View>: View {
    private let showsTrailingBorder: Bool
    private let isAlternateRow: Bool
    private let content: Content

    public init(
        showsTrailingBorder: Bool = true,
        isAlternateRow: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.showsTrailingBorder = showsTrailingBorder
        self.isAlternateRow = isAlternateRow
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            content
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isAlternateRow ? SlateColor.tableRowStripe : Color.clear)
        .overlay(alignment: .trailing) {
            if showsTrailingBorder {
                Rectangle()
                    .fill(SlateColor.databaseGridCellBorder)
                    .frame(width: SlateGeometry.strokeHairline)
            }
        }
    }
}

/// Cellule texte simple (champ Texte/Texte long).
public struct DatabaseTextCellView: View {
    private let text: String
    private let isPlaceholder: Bool

    public init(_ text: String, isPlaceholder: Bool = false) {
        self.text = text
        self.isPlaceholder = isPlaceholder
    }

    public var body: some View {
        Text(text)
            .slateFont(SlateFont.body)
            .foregroundStyle(isPlaceholder ? SlateColor.textTertiary : SlateColor.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

/// Cellule numerique (champ Nombre -- entier, decimal, %, devise). Chiffres tabulaires.
public struct DatabaseNumberCellView: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .slateFont(SlateTextStyle(size: 15, relativeTo: .body, tabularNums: true))
            .foregroundStyle(SlateColor.textPrimary)
    }
}

/// Cellule date (avec ou sans heure). Chiffres tabulaires (artboard A :
/// "font-variant-numeric: tabular-nums").
public struct DatabaseDateCellView: View {
    private let text: String
    private let isPlaceholder: Bool

    public init(_ text: String, isPlaceholder: Bool = false) {
        self.text = text
        self.isPlaceholder = isPlaceholder
    }

    public var body: some View {
        Text(text)
            .slateFont(SlateTextStyle(size: 15, relativeTo: .body, tabularNums: true))
            .foregroundStyle(isPlaceholder ? SlateColor.textTertiary : SlateColor.textPrimary)
    }
}

/// Cellule URL / E-mail / Telephone : rendue en `text.link` (reutilise le token existant
/// de `SlateSemanticColors.swift`, pas une nouvelle teinte).
public struct DatabaseURLCellView: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .slateFont(SlateFont.body)
            .foregroundStyle(SlateColor.textLink)
            .underline()
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

/// Cellule Personne : avatar + nom, ou "Non attribue" en placeholder (artboard A).
public struct DatabasePersonCellView: View {
    private let name: String
    private let initials: String
    private let accent: SlateAccentColor?

    /// `accent == nil` ET `initials.isEmpty` rend l'etat "Non attribue" (artboard A :
    /// texte seul en `text.disabled`, aucun avatar).
    public init(name: String, initials: String, accent: SlateAccentColor?) {
        self.name = name
        self.initials = initials
        self.accent = accent
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            if !initials.isEmpty {
                DatabaseAvatarView(initials: initials, accent: accent)
            }
            Text(name)
                .slateFont(SlateFont.body)
                .foregroundStyle(initials.isEmpty ? SlateColor.textDisabled : SlateColor.textPrimary)
        }
    }
}

/// Cellule Selection unique/multiple : une ou plusieurs `DatabasePillView` (artboard A,
/// colonne "Etiquettes").
public struct DatabaseTagsCellView: View {
    private let tags: [(title: String, style: SlateDatabasePillStyle)]

    public init(tags: [(title: String, style: SlateDatabasePillStyle)]) {
        self.tags = tags
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                DatabasePillView(tag.title, style: tag.style, isCompact: true)
            }
        }
    }
}

#Preview("DatabaseCellViews - ligne complete, clair") {
    DatabaseCellRowPreview()
        .environment(\.colorScheme, .light)
}

#Preview("DatabaseCellViews - ligne complete, sombre") {
    DatabaseCellRowPreview()
        .environment(\.colorScheme, .dark)
}

private struct DatabaseCellRowPreview: View {
    var body: some View {
        HStack(spacing: 0) {
            DatabaseGridCell { DatabaseTextCellView("Editeur de blocs") }
                .frame(width: 220)
            DatabaseGridCell {
                DatabasePillView("En cours", style: SlateDatabasePillStyle(accent: .blue, bullet: .square))
            }
            .frame(width: 130)
            DatabaseGridCell { DatabasePersonCellView(name: "Camille", initials: "CM", accent: .purple) }
                .frame(width: 150)
            DatabaseGridCell { DatabaseDateCellView("12 sept. 2026") }
                .frame(width: 130)
            DatabaseGridCell { DatabaseProgressCellView(fraction: 0.72, percentText: "72 %") }
                .frame(width: 130)
            DatabaseGridCell(showsTrailingBorder: false) {
                DatabaseTagsCellView(tags: [
                    ("v1", SlateDatabasePillStyle(accent: .purple)),
                    ("bloquant", SlateDatabasePillStyle(accent: .orange))
                ])
            }
            .frame(width: 200)
        }
        .background(SlateColor.bgEditor)
        .overlay(Rectangle().stroke(SlateColor.databaseGridCellBorder))
    }
}

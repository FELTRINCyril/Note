import SwiftUI
import SlateModel
import SlateUI

/// Cellule d'une note dans la colonne de liste (spec E3, "NoteCell") : compose la
/// primitive generique `ListCell` (`SlateUI`) avec tout ce qui est propre a une
/// `Note` - titre, extrait, indicateurs epingle/favori/verrouille, date relative.
///
/// `referenceDate` est fourni par l'appelant (`NoteListView`) plutot que lu directement
/// sur `note.modifiedAt` : la date affichee doit rester coherente avec la date qui a
/// determine le groupe de cette note (`modifiedAt` par defaut, `createdAt` si
/// l'utilisateur trie par date de creation - voir `NoteDateGrouper`).
struct NoteCell: View {
    let note: Note
    let isSelected: Bool
    let isFocused: Bool
    let referenceDate: Date
    let calendar: Calendar
    let now: Date

    @Environment(\.slateIsOnAccentFill) private var isOnAccentFill

    var body: some View {
        ListCell(
            title: displayedTitle,
            isTitlePlaceholder: isTitleEmpty,
            snippet: displayedSnippet,
            isSnippetPlaceholder: isSnippetPlaceholder,
            isSelected: isSelected,
            isFocused: isFocused,
            accessibilityLabel: accessibilityLabelText,
            leading: { indicators },
            trailing: { dateLabel }
        )
    }

    // MARK: - Titre

    private var isTitleEmpty: Bool {
        note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedTitle: String {
        isTitleEmpty ? String(localized: "noteList.cell.title.placeholder", bundle: .module) : note.title
    }

    // MARK: - Extrait

    /// Vrai si l'extrait affiche est un texte de remplacement (verrouillee ou vide),
    /// donc rendu en `text.tertiary` plutot qu'en `text.secondary` - voir
    /// `ListCell.isSnippetPlaceholder`.
    private var isSnippetPlaceholder: Bool {
        note.isLocked || note.snippetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Regle de confidentialite de la spec E3 : une note verrouillee n'affiche JAMAIS
    /// son extrait, meme si `snippetText` est deja calcule et present en base - c'est
    /// une regle de presentation, distincte de la regle (deja appliquee cote
    /// `NoteListQuery`) qui exclut le contenu verrouille de la recherche.
    private var displayedSnippet: String {
        if note.isLocked {
            return String(localized: "noteList.cell.snippet.locked", bundle: .module)
        }
        if note.snippetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "noteList.cell.snippet.empty", bundle: .module)
        }
        return note.snippetText
    }

    // MARK: - Indicateurs (avant le titre, spec E3 : "11 pt, avant le titre")

    @ViewBuilder
    private var indicators: some View {
        HStack(spacing: Spacing.xs) {
            if note.isPinned {
                indicatorIcon("pin.fill", color: SlateColor.accentDefault)
            }
            if note.isFavorite {
                indicatorIcon("star.fill", color: SlateColor.semanticWarning)
            }
            if note.isLocked {
                indicatorIcon("lock.fill", color: SlateColor.textSecondary)
            }
        }
    }

    private func indicatorIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .slateIconFont(SlateGeometry.noteCellIndicatorIconSize, relativeTo: .subheadline)
            .foregroundStyle(SlateColor.foreground(color, onAccentFill: isOnAccentFill))
    }

    // MARK: - Date

    private var dateLabel: some View {
        Text(NoteRelativeDateFormatter.string(for: referenceDate, calendar: calendar, now: now))
            .slateFont(SlateFont.caption)
            .foregroundStyle(SlateColor.foregroundSecondary(SlateColor.textSecondary, onAccentFill: isOnAccentFill))
    }

    // MARK: - Accessibilite

    /// Compose un libelle du genre de l'exemple de la spec E3 : "Budget 2027,
    /// verrouillee, 09:48" - le titre (ou son placeholder), chaque indicateur present
    /// (jamais la couleur seule, voir `ListCell`), puis la date. Les indicateurs
    /// absents ne produisent aucun mot ("Jamais la couleur seule" ne veut pas dire
    /// "toujours les trois mots").
    private var accessibilityLabelText: String {
        var components = [displayedTitle]
        if note.isPinned {
            components.append(String(localized: "noteList.cell.accessibility.pinned", bundle: .module))
        }
        if note.isFavorite {
            components.append(String(localized: "noteList.cell.accessibility.favorite", bundle: .module))
        }
        if note.isLocked {
            components.append(String(localized: "noteList.cell.accessibility.locked", bundle: .module))
        }
        components.append(NoteRelativeDateFormatter.string(for: referenceDate, calendar: calendar, now: now))
        return components.joined(separator: ", ")
    }
}

#Preview("NoteCell - catalogue (clair)") {
    NoteCellCatalogPreview()
        .frame(width: 300)
        .background(SlateColor.bgList)
}

#Preview("NoteCell - catalogue (sombre)") {
    NoteCellCatalogPreview()
        .frame(width: 300)
        .background(SlateColor.bgList)
        .preferredColorScheme(.dark)
}

#Preview("NoteCell - selectionnee, indicateurs cumules") {
    let note = Note(
        title: "Budget 2027",
        modifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
        isPinned: true,
        isLocked: true,
        isFavorite: true
    )
    NoteCell(
        note: note,
        isSelected: true,
        isFocused: false,
        referenceDate: note.modifiedAt,
        calendar: .current,
        now: Date(timeIntervalSince1970: 1_700_000_000)
    )
    .frame(width: 300)
    .background(SlateColor.bgList)
}

/// Rassemble quelques etats representatifs de `NoteCell` pour les previews.
private struct NoteCellCatalogPreview: View {
    var body: some View {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        VStack(spacing: 0) {
            NoteCell(
                note: Note(title: "Architecture de l'editeur", modifiedAt: now),
                isSelected: false,
                isFocused: false,
                referenceDate: now,
                calendar: .current,
                now: now
            )
            NoteCell(
                note: makeNoteWithSnippet(title: "Rituels d'equipe", snippet: "Lundi revue de sprint.", now: now),
                isSelected: false,
                isFocused: false,
                referenceDate: now,
                calendar: .current,
                now: now
            )
            NoteCell(
                note: Note(title: "", modifiedAt: now),
                isSelected: false,
                isFocused: false,
                referenceDate: now,
                calendar: .current,
                now: now
            )
        }
    }

    private func makeNoteWithSnippet(title: String, snippet: String, now: Date) -> Note {
        let note = Note(title: title, modifiedAt: now)
        note.snippetText = snippet
        return note
    }
}

import SwiftUI
import SlateModel
import SlateUI

/// Ligne de `TrashView` (design P3, artboard B) : titre + metadonnees ("Supprimee il y
/// a 2 jours - etait dans Produit - expire dans 28 jours"), actions Restaurer/Supprimer,
/// ou "Deverrouiller pour restaurer" a la place des actions pour une note verrouillee
/// (regle ferme du design : "une note verrouillee ne montre ni contenu, ni extrait, ni
/// pieces jointes" - cette ligne ne montre donc jamais d'extrait, verrouillee ou non,
/// contrairement a `NoteCell`).
struct TrashRowView: View {
    let note: Note
    let now: Date
    let calendar: Calendar
    let onRestore: () -> Void
    let onDeletePermanently: () -> Void

    private var trashedAt: Date { note.trashedAt ?? now }

    private var remainingDays: Int {
        TrashRetentionPolicy.remainingDays(trashedAt: trashedAt, now: now, calendar: calendar)
    }

    private var isExpiringSoon: Bool { remainingDays <= 1 }

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                titleRow
                metadataText
                    .slateFont(SlateFont.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingContent
        }
        .padding(.horizontal, SlateGeometry.noteCellPaddingHorizontal)
        .frame(minHeight: SlateGeometry.noteCellMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(SlateColor.separator).frame(height: SlateGeometry.strokeHairline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
    }

    // MARK: - Titre

    private var isTitleEmpty: Bool {
        note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedTitle: String {
        isTitleEmpty ? String(localized: "noteList.cell.title.placeholder", bundle: .module) : note.title
    }

    @ViewBuilder
    private var titleRow: some View {
        HStack(spacing: Spacing.xs) {
            if note.isLocked {
                Image(systemName: "lock.fill")
                    .slateIconFont(SlateGeometry.noteCellIndicatorIconSize, relativeTo: .subheadline)
                    .foregroundStyle(SlateColor.textSecondary)
            }
            Text(displayedTitle)
                .slateFont(SlateFont.listTitle)
                .foregroundStyle(isTitleEmpty ? SlateColor.textTertiary : SlateColor.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Metadonnees

    /// Compose visuellement les memes segments que `TrashRowMetadataFormatter` (source
    /// de verite pour le libelle COMPLET, voir `accessibilityLabelText`), mais en
    /// `Text` separes pour pouvoir teinter le seul segment d'expiration en
    /// `semanticWarningText` quand elle est imminente (design : "expire demain" en
    /// ambre dans "Brouillon newsletter juin").
    private var metadataText: Text {
        var segments: [Text] = []
        if note.isLocked {
            let locked = Text(String(localized: "trash.row.locked", bundle: .module))
            segments.append(locked.foregroundStyle(SlateColor.textSecondary))
        }
        segments.append(
            Text(TrashElapsedFormatter.string(trashedAt: trashedAt, now: now, calendar: calendar))
                .foregroundStyle(SlateColor.textSecondary)
        )
        if !note.isLocked, let folderName = note.folder?.name {
            let template = String(localized: "trash.row.wasInFolder", bundle: .module)
            segments.append(Text(String(format: template, folderName)).foregroundStyle(SlateColor.textSecondary))
        }
        let expirationColor = isExpiringSoon ? SlateColor.semanticWarningText : SlateColor.textSecondary
        segments.append(
            Text(TrashExpirationFormatter.string(remainingDays: remainingDays))
                .foregroundStyle(expirationColor)
        )

        let separator = Text(String(localized: "trash.row.metadataSeparator", bundle: .module))
            .foregroundStyle(SlateColor.textSecondary)
        return segments.dropFirst().reduce(segments[0]) { partial, next in partial + separator + next }
    }

    private var accessibilityLabelText: String {
        let metadata = TrashRowMetadataFormatter.string(
            isLocked: note.isLocked,
            trashedAt: trashedAt,
            folderName: note.folder?.name,
            now: now,
            calendar: calendar
        )
        return "\(displayedTitle), \(metadata)"
    }

    // MARK: - Actions

    @ViewBuilder
    private var trailingContent: some View {
        if note.isLocked {
            Text(String(localized: "trash.row.unlockToRestore", bundle: .module))
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textSecondary)
        } else {
            HStack(spacing: Spacing.xs) {
                Button(action: onRestore) {
                    Label(String(localized: "trash.row.restore", bundle: .module), systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(String(localized: "trash.row.delete", bundle: .module), action: onDeletePermanently)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

#Preview("TrashRowView") {
    let note = Note(title: "Ancien plan de lancement")
    note.trashedAt = Calendar.current.date(byAdding: .day, value: -2, to: .now)
    return VStack(spacing: 0) {
        TrashRowView(note: note, now: .now, calendar: .current, onRestore: {}, onDeletePermanently: {})
    }
    .background(SlateColor.bgList)
}

#Preview("TrashRowView - verrouillee") {
    let note = Note(title: "Comptes bancaires", isLocked: true)
    note.trashedAt = Calendar.current.date(byAdding: .day, value: -9, to: .now)
    return VStack(spacing: 0) {
        TrashRowView(note: note, now: .now, calendar: .current, onRestore: {}, onDeletePermanently: {})
    }
    .background(SlateColor.bgList)
}

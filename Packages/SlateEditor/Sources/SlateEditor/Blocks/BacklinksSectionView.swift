import SlateModel
import SlateUI
import SwiftUI

/// Section "Mentionnee dans..." affichee sous le contenu d'une note (Phase 16,
/// docs/16_liens_internes.md : "Backlinks... optionnel mais precieux"). Liste les
/// notes qui contiennent un bloc `pageLink` vers la note affichee
/// (`PageLinkBacklinks.notes(linkingTo:in:)`, calculee par `NoteDocumentView`), chaque
/// ligne cliquable navigue vers la note source -- meme fermeture `onSelect` que
/// `PageLinkBlockContentView`.
struct BacklinksSectionView: View {
    let notes: [Note]
    let onSelect: (Note) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(EditorStrings.backlinksSectionTitle)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textSecondary)

            ForEach(notes, id: \.id) { note in
                Button { onSelect(note) } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "arrow.turn.down.right")
                            .slateIconFont(SlateGeometry.sidebarIconSize)
                            .foregroundStyle(SlateColor.textSecondary)
                        Text(displayedTitle(for: note))
                            .slateFont(SlateFont.body)
                            .foregroundStyle(SlateColor.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, Spacing.lg)
        .padding(.horizontal, Spacing.sm)
    }

    private func displayedTitle(for note: Note) -> String {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? EditorStrings.pageLinkUntitled : title
    }
}

import SwiftUI
import SlateModel
import SlateEditor

/// Colonne detail : bascule entre l'etat vide (`NoteDetailColumnPlaceholderView`,
/// deja livre en Phase 3) et le rendu de la note selectionnee (`SlateEditor.
/// NoteDocumentView`, Phase 5.1).
///
/// Point d'integration unique demande par la Phase 5.1 (`docs/05_editeur_blocs.md`,
/// sous-etape 5.1, point 6) : c'est ICI, et seulement ici, que `SlateFeatures` fournit
/// a `SlateEditor` les chaines localisees (`NoteEditorStrings`) et la ligne de
/// metadonnees deja formatee (`NoteHeaderMetadataFormatter`) -- `SlateEditor` lui-meme
/// ne sait ni localiser une chaine (voir `NoteEditorStrings`) ni formater une date
/// (sens des dependances, `docs/00_architecture.md`).
struct NoteDetailColumnView: View {
    @Environment(\.appState) private var appState
    @State private var showsComingSoonAlert = false
    @State private var comingSoonMessage = ""

    var body: some View {
        Group {
            if let note = appState.selectedNote {
                NoteDocumentView(
                    note: note,
                    metadataLine: metadataLine(for: note),
                    strings: strings,
                    onAddIcon: {
                        presentComingSoon(String(localized: "noteDetail.addIcon.comingSoon", bundle: .module))
                    },
                    onAddCover: {
                        presentComingSoon(String(localized: "noteDetail.addCover.comingSoon", bundle: .module))
                    }
                )
            } else {
                NoteDetailColumnPlaceholderView()
            }
        }
        .alert(
            String(localized: "noteDetail.comingSoon.title", bundle: .module),
            isPresented: $showsComingSoonAlert
        ) {
            Button(String(localized: "action.ok", bundle: .module), role: .cancel) {}
        } message: {
            Text(comingSoonMessage)
        }
    }

    private func metadataLine(for note: Note) -> String {
        let wordCount = WordCounter.wordCount(in: note.plainText)
        return NoteHeaderMetadataFormatter.string(modifiedAt: note.modifiedAt, wordCount: wordCount)
    }

    private var strings: NoteEditorStrings {
        NoteEditorStrings(
            untitledPlaceholder: String(localized: "noteDetail.title.placeholder", bundle: .module),
            addIconLabel: String(localized: "noteDetail.addIcon.label", bundle: .module),
            addIconAccessibilityLabel: String(localized: "noteDetail.addIcon.accessibilityLabel", bundle: .module),
            addCoverLabel: String(localized: "noteDetail.addCover.label", bundle: .module),
            addCoverAccessibilityLabel: String(localized: "noteDetail.addCover.accessibilityLabel", bundle: .module),
            noteIconAccessibilityLabel: String(localized: "noteDetail.icon.accessibilityLabel", bundle: .module),
            noteCoverAccessibilityLabel: String(localized: "noteDetail.cover.accessibilityLabel", bundle: .module),
            unsupportedBlockLabelPrefix: String(localized: "noteDetail.unsupportedBlock.prefix", bundle: .module)
        )
    }

    private func presentComingSoon(_ message: String) {
        comingSoonMessage = message
        showsComingSoonAlert = true
    }
}

#Preview("NoteDetailColumnView - aucune note") {
    NoteDetailColumnView()
        .frame(width: 900, height: 700)
}

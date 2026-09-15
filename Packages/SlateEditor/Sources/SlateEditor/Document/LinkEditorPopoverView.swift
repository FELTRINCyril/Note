import AppKit
import SlateModel
import SlateUI
import SwiftData
import SwiftUI

/// Popover d'edition de lien (docs/07_typographie_formatage.md, artboard P1 C) :
/// creation (Cmd+K / bouton "lien" sur une selection sans lien -- champ d'URL focalise,
/// titre "Lier <texte selectionne>") et edition d'un lien EXISTANT (URL affichee +
/// Modifier/Copier/Retirer). Presente en `.popover` par `FormatBarView`, meme precedent
/// que `FormatColorPopoverView` (voir sa documentation de tete).
///
/// ## Recherche de notes (Phase 16, docs/16_liens_internes.md)
/// La recherche de notes est desormais REELLE (voir `noteSearchResults`) : selectionner
/// un resultat pose un lien `slate://note/<uuid>` (`SlateNoteURLResolver`) sur le texte
/// selectionne, resolu au clic par `RichTextEditingRepresentable+PageMention.swift`.
/// Reutilise `PageMentionFilter`/`NoteMentionCandidate` (memes types que le selecteur
/// "@"/"[[") : meme filtrage flou, pas de duplication de logique de recherche. Ce
/// popover reste volontairement plus simple que le selecteur "@" : pas d'entree
/// "Creer une page" ici (le texte deja selectionne n'est pas un TITRE de note, y greffer
/// une creation a la volee melangerait deux intentions differentes) -- une note
/// inexistante se cree via "@"/"[[" dans le corps du texte, pas depuis ce popover.
struct LinkEditorPopoverView: View {
    let block: Block
    let editorController: EditorController
    let range: RichTextRange
    let selectedText: String
    let onDismiss: () -> Void

    /// `true` force l'affichage du champ d'URL meme si `range` porte deja un lien --
    /// declenche par l'action "Modifier le lien" (voir `editingContent(existingLink:)`).
    @State private var isEditingURL = false
    @State private var urlText = ""
    @State private var noteSearchQuery = ""
    @FocusState private var isURLFieldFocused: Bool

    @Environment(\.modelContext) private var modelContext

    private var existingLink: URL? { editorController.currentLink(in: block, range: range) }

    /// Resultats de recherche pour `noteSearchQuery`, note en cours d'edition exclue
    /// (se lier a soi-meme n'a pas de sens) -- meme regle que le selecteur "@"/"[[".
    private var noteSearchResults: [NoteMentionMatch] {
        guard !noteSearchQuery.isEmpty else { return [] }
        let predicate = #Predicate<Note> { !$0.isTrashed }
        guard let notes = try? modelContext.fetch(FetchDescriptor<Note>(predicate: predicate)) else { return [] }
        let currentNoteID = block.note?.id
        let candidates = notes
            .filter { $0.id != currentNoteID }
            .map { NoteMentionCandidate(id: $0.id, title: $0.title) }
        return PageMentionFilter.match(query: noteSearchQuery, in: candidates)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let existingLink, !isEditingURL {
                editingContent(existingLink: existingLink)
            } else {
                urlEntryContent
            }
        }
        .padding(Spacing.md)
        .frame(width: 280)
        .background(SlateColor.surfacePrimary)
        .onAppear {
            urlText = existingLink?.absoluteString ?? ""
            isURLFieldFocused = existingLink == nil
        }
    }

    // MARK: - Creation / edition de l'URL

    private var urlEntryContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(EditorStrings.linkPopoverCreateTitle(selectedText: selectedText))
                .slateFont(SlateFont.bodyEmphasis)
                .foregroundStyle(SlateColor.textPrimary)
                .lineLimit(1)

            TextField(EditorStrings.linkPopoverURLFieldPlaceholder, text: $urlText)
                .textFieldStyle(.roundedBorder)
                .focused($isURLFieldFocused)
                .onSubmit(applyURL)

            // Recherche de notes (Phase 16) : voir la documentation de tete de fichier.
            TextField(EditorStrings.linkPopoverNoteSearchPlaceholder, text: $noteSearchQuery)
                .textFieldStyle(.roundedBorder)

            if !noteSearchResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(noteSearchResults.prefix(5)) { match in
                        Button { applyNoteLink(match.candidate) } label: {
                            Text(displayedTitle(match.candidate.title))
                                .slateFont(SlateFont.body)
                                .foregroundStyle(SlateColor.textPrimary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, Spacing.xs)
                    }
                }
            }

            HStack {
                Spacer()
                Button(EditorStrings.linkPopoverCancel) { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(SlateColor.textSecondary)
                Button(EditorStrings.linkPopoverApply, action: applyURL)
                    .buttonStyle(.borderedProminent)
                    .disabled(normalizedURL == nil)
            }
        }
    }

    // MARK: - Survol d'un lien existant (URL + actions)

    private func editingContent(existingLink: URL) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(existingLink.absoluteString)
                .slateFont(SlateFont.body)
                .foregroundStyle(SlateColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Divider()

            Button {
                urlText = existingLink.absoluteString
                isEditingURL = true
            } label: {
                Label(EditorStrings.linkPopoverEditTitle, systemImage: "pencil")
                    .foregroundStyle(SlateColor.textPrimary)
            }
            .buttonStyle(.plain)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(existingLink.absoluteString, forType: .string)
            } label: {
                Label(EditorStrings.linkPopoverCopyAddress, systemImage: "doc.on.doc")
                    .foregroundStyle(SlateColor.textPrimary)
            }
            .buttonStyle(.plain)

            Button {
                editorController.setLink(nil, in: block, range: range)
                onDismiss()
            } label: {
                // Action destructive (docs/07, design P1 artboard C) : SEUL le glyphe
                // porte `semantic.error`, le libelle reste `text.primary` -- le rouge sur
                // surface sombre mesure ~3,9:1, insuffisant pour du TEXTE (AA = 4,5:1).
                Label {
                    Text(EditorStrings.linkPopoverRemoveLink).foregroundStyle(SlateColor.textPrimary)
                } icon: {
                    Image(systemName: "link.badge.minus").foregroundStyle(SlateColor.semanticError)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Validation de l'URL

    /// `URL` valide construite depuis `urlText`, en ajoutant `https://` si aucun schema
    /// n'est present (le champ n'exige pas que l'utilisateur tape le schema) -- `nil`
    /// si le texte est vide ou ne forme pas une URL valide (desactive le bouton
    /// "Appliquer" plutot que d'accepter une saisie invalide silencieusement).
    private var normalizedURL: URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://" + trimmed)
    }

    private func applyURL() {
        guard let url = normalizedURL else { return }
        editorController.setLink(url, in: block, range: range)
        isEditingURL = false
        onDismiss()
    }

    /// Pose un lien interne `slate://note/<uuid>` (Phase 16) vers `candidate` sur le
    /// texte selectionne -- meme action de fond que `applyURL()`, URL construite par
    /// `SlateNoteURLResolver.url(forNoteID:)` plutot que tapee.
    private func applyNoteLink(_ candidate: NoteMentionCandidate) {
        editorController.setLink(SlateNoteURLResolver.url(forNoteID: candidate.id), in: block, range: range)
        isEditingURL = false
        onDismiss()
    }

    private func displayedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? EditorStrings.pageLinkUntitled : trimmed
    }
}

import AppKit
import SlateModel
import SlateUI
import SwiftUI

/// Popover d'edition de lien (docs/07_typographie_formatage.md, artboard P1 C) :
/// creation (Cmd+K / bouton "lien" sur une selection sans lien -- champ d'URL focalise,
/// titre "Lier <texte selectionne>") et edition d'un lien EXISTANT (URL affichee +
/// Modifier/Copier/Retirer). Presente en `.popover` par `FormatBarView`, meme precedent
/// que `FormatColorPopoverView` (voir sa documentation de tete).
///
/// ## Perimetre volontairement REDUIT : recherche de notes
/// L'artboard montre aussi une recherche de notes ("chercher une note...", "Creer une
/// note...") -- c'est la Phase 16 (liens internes & sous-pages, voir PLAN.md), PAS cette
/// phase. Le champ ci-dessous est present et STRUCTURELLEMENT pret a l'accueillir
/// (meme emplacement, meme style), mais desactive et sans aucune recherche reelle
/// branchee derriere : la Phase 16 le remplacera par un vrai champ de recherche, sans
/// avoir a redessiner ce popover.
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
    @FocusState private var isURLFieldFocused: Bool

    private var existingLink: URL? { editorController.currentLink(in: block, range: range) }

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

            // Recherche de notes : structure prete pour la Phase 16, voir la
            // documentation de tete de fichier. Desactivee, aucune recherche reelle.
            TextField(EditorStrings.linkPopoverNoteSearchPlaceholder, text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .disabled(true)
                .opacity(SlateOpacity.disabled)

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
}

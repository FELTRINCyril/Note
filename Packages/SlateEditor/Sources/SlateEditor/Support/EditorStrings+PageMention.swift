import Foundation

/// Chaines du selecteur de page "@"/"[[" et du bloc `pageLink` (Phase 16,
/// docs/16_liens_internes.md). Fichier separe de `EditorStrings.swift` (qui frole deja
/// la limite de longueur de fichier de `CLAUDE.md` §5, meme motif que les extensions
/// `EditorController+*.swift`) mais meme convention : chaque acces passe par
/// `String(localized:bundle: .module)`, jamais d'interpolation dans une `defaultValue`
/// (voir la documentation de `EditorStrings.formatBarStyleHeading(_:)` pour l'incident
/// que cette regle evite).
extension EditorStrings {
    // MARK: - Bloc `pageLink` (`PageLinkBlockContentView`)

    /// Titre affiche quand la note ciblee par un `pageLink` a ete supprimee
    /// (docs/16, "Orphelins").
    static var pageLinkDeletedPage: String {
        String(localized: "editor.pageLink.deletedPage", bundle: .module)
    }

    /// Titre affiche quand la note ciblee existe mais n'a pas de titre.
    static var pageLinkUntitled: String {
        String(localized: "editor.pageLink.untitled", bundle: .module)
    }

    // MARK: - Selecteur "@"/"[[" (`PageMentionOverlay`)

    static var pageMentionSectionTitle: String {
        String(localized: "editor.pageMention.section.title", bundle: .module)
    }

    static var pageMentionEmptyState: String {
        String(localized: "editor.pageMention.emptyState", bundle: .module)
    }

    /// Libelle de l'entree "Creer la page <query>" -- cle constante avec un `%@`,
    /// jamais `\(query)` interpole dans la `defaultValue` (voir la documentation de
    /// tete de fichier).
    static func pageMentionCreateTitle(_ query: String) -> String {
        let template = String(localized: "editor.pageMention.create.title", bundle: .module)
        return String(format: template, query)
    }

    static var pageMentionCreateSubtitle: String {
        String(localized: "editor.pageMention.create.subtitle", bundle: .module)
    }

    // MARK: - Backlinks (`BacklinksSectionView`)

    static var backlinksSectionTitle: String {
        String(localized: "editor.backlinks.section.title", bundle: .module)
    }
}

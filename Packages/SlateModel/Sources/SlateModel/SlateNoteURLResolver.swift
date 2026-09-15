import Foundation

/// Resolution du schema d'URL interne `slate://note/<uuid>` (docs/16_liens_internes.md,
/// docs/11_organisation_notes.md "Copier le lien interne").
///
/// Le SEUL producteur de ce schema reste `SlateFeatures.NoteInternalLink.url(for:)`
/// (Phase 11) : ce type-ci n'ecrit jamais d'URL, il n'en fait QUE la lecture inverse
/// (chaine -> `UUID`), pour rester utilisable depuis `SlateEditor` (qui ne peut pas
/// dependre de `SlateFeatures`, sens des dependances -- voir `docs/00_architecture.md`)
/// sans dupliquer la construction elle-meme. Les deux DOIVENT rester en accord sur le
/// schema (`"slate"`) et l'hote (`"note"`) : documente ici et la, pas de constante
/// partagee entre modules pour une chaine aussi courte et stable.
public enum SlateNoteURLResolver {
    /// `UUID` cible d'un lien `slate://note/<uuid>`, ou `nil` si `url` ne suit pas ce
    /// schema (autre schema, hote different, chemin absent ou non-UUID). Logique PURE
    /// (aucun `ModelContext`) : trouver la `Note` correspondante est la responsabilite
    /// de l'appelant (voir `PageLinkBlockContentView`, qui resout ensuite via
    /// `FetchDescriptor<Note>`).
    public static func noteID(in url: URL) -> UUID? {
        guard url.scheme?.lowercased() == "slate", url.host?.lowercased() == "note" else { return nil }
        let uuidString = url.pathComponents.last { $0 != "/" } ?? ""
        return UUID(uuidString: uuidString)
    }

    /// Construit un lien `slate://note/<uuid>` vers `noteID` -- meme forme EXACTE que
    /// `SlateFeatures.NoteInternalLink.url(for:)` (Phase 11, "Copier le lien interne"),
    /// dupliquee ici volontairement plutot que reutilisee : `SlateEditor` (le popover
    /// d'edition de lien, Phase 16) ne peut pas dependre de `SlateFeatures` (sens des
    /// dependances, voir `docs/00_architecture.md`). Les deux DOIVENT rester en accord,
    /// voir la documentation de tete de ce type.
    public static func url(forNoteID noteID: UUID) -> URL {
        URL(string: "slate://note/\(noteID.uuidString)") ?? URL(fileURLWithPath: "/")
    }
}

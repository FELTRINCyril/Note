import Foundation
import SlateModel

/// URL de lien interne d'une note ("Copier le lien interne", design P3 artboard A).
///
/// Schema provisoire `slate://note/<uuid>` : aucune resolution de ce schema (ouverture
/// d'un lien colle, navigation Phase 16 "sous-pages"/`pageLink`) n'existe encore dans le
/// code - seule la production du lien est demandee par cette phase. A revoir quand la
/// Phase 16 (liens entre notes, `BlockType.pageLink`) definira le schema definitif ;
/// documente ici pour que cette decision provisoire soit facile a retrouver et remplacer.
public enum NoteInternalLink {
    public static func url(for note: Note) -> URL {
        // Construction manuelle plutot que `URLComponents` : un UUID ne contient jamais
        // de caractere a pourcent-encoder, `URLComponents` ajouterait un cout inutile ici.
        URL(string: "slate://note/\(note.id.uuidString)") ?? URL(fileURLWithPath: "/")
    }
}

import Foundation
import SwiftData

/// Requete inverse des liens de page (docs/16_liens_internes.md, "Backlinks : afficher
/// 'mentionnee dans...' sur la page cible"). Meme esprit que `SidebarNavigation` :
/// une requete pure, independante de toute vue SwiftUI, `@MainActor` parce qu'elle
/// touche un `ModelContext`.
///
/// ## Strategie : tout filtrer en memoire, apres un fetch SANS predicat
/// Deux obstacles empechent un `#Predicate` de faire ce travail cote store :
/// `BlockAttributes` est une struct `Codable` aplatie en colonnes par SwiftData (voir sa
/// documentation), donc `linkedNoteID` n'est pas un champ que `#Predicate` peut
/// atteindre ; et `BlockType` (enum `String`-backed) ne peut pas non plus y etre compare
/// directement -- verifie empiriquement pendant cette tache : capturer une constante
/// `BlockType` leve `unsupportedPredicate` a l'execution, et `$0.type.rawValue` provoque
/// un `fatalError` de validation de schema ("rawValue is not a member of BlockType"),
/// `#Predicate` n'exposant que les membres STOCKES d'un `@Model`, jamais les membres
/// synthetises d'un type `RawRepresentable` par ailleurs stocke tel quel. Cette requete
/// fetch donc TOUS les `Block` du store puis filtre entierement en Swift -- acceptable
/// pour cette fonctionnalite (backlinks, consultee a l'ouverture d'une note, jamais a
/// chaque frappe), documente comme piste d'optimisation si le volume total de blocs
/// devait un jour le justifier (ex. stocker un `BlockType` sous forme de `String` brut
/// dediee a l'indexation, en plus de l'enum -- hors perimetre de cette phase).
@MainActor
public enum PageLinkBacklinks {
    /// Notes qui contiennent au moins un bloc `pageLink` pointant vers `target`,
    /// triees par titre (ordre naturel, stable par `id`). Exclut toujours `target`
    /// elle-meme (un lien d'une note vers elle-meme, s'il existait, ne serait pas un
    /// "backlink" au sens ou l'entend cette fonctionnalite).
    public static func notes(linkingTo target: Note, in context: ModelContext) throws -> [Note] {
        let allBlocks = try context.fetch(FetchDescriptor<Block>())

        let targetID = target.id
        var seenNoteIDs = Set<UUID>()
        var results: [Note] = []
        for block in allBlocks {
            guard block.type == .pageLink,
                  block.attributes.linkedNoteID == targetID,
                  let sourceNote = block.note,
                  sourceNote.id != targetID,
                  seenNoteIDs.insert(sourceNote.id).inserted
            else { continue }
            results.append(sourceNote)
        }

        return results.sorted { lhs, rhs in
            let comparison = lhs.title.localizedStandardCompare(rhs.title)
            return comparison == .orderedSame ? lhs.id.uuidString < rhs.id.uuidString : comparison == .orderedAscending
        }
    }
}

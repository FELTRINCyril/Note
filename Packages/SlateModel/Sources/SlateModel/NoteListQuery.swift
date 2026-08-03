import Foundation
import SwiftData

/// Couche de requetes pour la liste de notes (colonne du milieu, Phase 4,
/// `docs/04_liste_notes.md` et la spec E3 de `design/04_liste_notes/`), independante de
/// toute vue SwiftUI - meme forme et meme raison d'etre que `SidebarNavigation`
/// (Phase 3) : un type `@MainActor` regroupant requetes testables depuis
/// `SlateModelTests` sans jamais construire d'UI.
///
/// Le regroupement temporel (Aujourd'hui / Hier / 7 jours / 30 jours / mois / annees)
/// n'est **pas** implemente ici : `docs/04_liste_notes.md` le confie explicitement a un
/// helper de `SlateFeatures` (`NoteDateGrouper`), en aval de ces requetes. Ce type ne
/// fournit que la matiere premiere deja filtree/triee ; grouper une liste triee par
/// date en tranches "Aujourd'hui"/"Hier"/... est une preoccupation de presentation, pas
/// de modele de donnees.
///
/// ## Portee : recursive, comme `Folder.noteCount`
///
/// "Les notes d'un dossier" inclut ici les notes de tous ses sous-dossiers, a n'importe
/// quelle profondeur. Decision deliberement **alignee** sur `Folder.noteCount`
/// (`SidebarOrdering.swift`), qui est deja recursif et exclut deja la corbeille : un
/// dossier affichant "12" dans la sidebar alors que sa liste de notes n'en montrerait
/// que 3 (les notes directes seulement) serait une incoherence visible et deroutante
/// pour l'utilisateur - exactement le risque signale par la consigne de cette tache.
/// Rester coherent avec ce compteur deja livre (Phase 3) prime sur toute autre
/// consideration ; si un jour la Phase 4 doit aussi offrir une vue "notes directes
/// seulement" (non demandee par `docs/04_liste_notes.md`), elle devra passer par une
/// nouvelle methode explicitement nommee, pas par un changement de comportement de
/// celle-ci.
///
/// ## Pourquoi le filtrage combine (dossier recursif, corbeille, epingle, recherche)
/// se fait en memoire et pas via `#Predicate`
///
/// Un `#Predicate` SwiftData ne sait filtrer que des proprietes stockees scalaires
/// d'une seule entite. Or ce type doit combiner :
/// - une traversee **recursive** de `Folder.subfolders` (une relation, pas un scalaire,
///   et de profondeur variable - non exprimable dans un seul `#Predicate`) ;
/// - la regle "extrait exclu de la recherche si la note est verrouillee", qui depend de
///   deux proprietes de la meme note (`isLocked` ET `plainText`) combinees par une
///   logique conditionnelle plus riche qu'une simple conjonction de predicats.
///
/// Le parti pris retenu, deja utilise par `SidebarNavigation.favoriteNotes(in:)` pour
/// une raison similaire (traversee de relation non triviale), est de faire porter au
/// `#Predicate` la seule partie qu'il sait exprimer nativement et de bon droit
/// (`!isTrashed`, un scalaire simple), puis de filtrer le reste en memoire sur le
/// resultat. Le volume concerne (les notes d'un espace de travail personnel) reste
/// largement dans l'ordre de grandeur ou ce filtrage en memoire est negligeable ; si ce
/// choix devait un jour poser un probleme de performance a grande echelle, il faudrait
/// re-evaluer une strategie a base d'un champ dedie (par ex. un `folderPathIDs` stocke
/// et aplati), pas avant.
@MainActor
public struct NoteListQuery {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Notes contenues dans `folder`, recursivement (voir la documentation de ce type),
    /// en excluant systematiquement la corbeille (`isTrashed`).
    ///
    /// - Parameter pinnedFilter: par defaut `.all`. La colonne de liste doit passer
    ///   `.excludingPinned` pour la matiere premiere de ses groupes de date (les notes
    ///   epinglees ne doivent apparaitre que dans leur section dediee, jamais
    ///   dupliquees - voir `NotePinnedFilter`) et `.pinnedOnly` pour cette section.
    /// - Parameter searchQuery: si non `nil` et non vide (apres suppression des
    ///   espaces de bordure), ne conserve que les notes dont le titre contient la
    ///   requete, ou dont le contenu (`plainText`) la contient **si la note n'est pas
    ///   verrouillee**. Une note verrouillee reste trouvable par son titre, jamais par
    ///   son contenu : c'est une regle de confidentialite explicite de la spec E3
    ///   ("l'extrait est exclu de la recherche si la note est verrouillee"), pas un
    ///   detail d'implementation - une note verrouillee ne doit pas fuir son contenu
    ///   via la recherche.
    /// - Parameter criterion: `.modifiedDate` par defaut (comportement de Notes
    ///   d'Apple, voir `docs/04_liste_notes.md`).
    /// - Parameter direction: `.descending` par defaut (les notes les plus recentes -
    ///   ou, en tri par titre, "Z" avant "A" - en tete).
    public func notes(
        in folder: Folder,
        pinned pinnedFilter: NotePinnedFilter = .all,
        matching searchQuery: String? = nil,
        sortedBy criterion: NoteSortCriterion = .modifiedDate,
        direction: SortDirection = .descending
    ) throws -> [Note] {
        let folderIDs = Self.folderAndDescendantIDs(of: folder)

        let predicate = #Predicate<Note> { note in !note.isTrashed }
        let descriptor = FetchDescriptor<Note>(predicate: predicate)
        var candidates = try context.fetch(descriptor).filter { note in
            guard let folderID = note.folder?.id else { return false }
            return folderIDs.contains(folderID)
        }

        switch pinnedFilter {
        case .all:
            break
        case .pinnedOnly:
            candidates = candidates.filter(\.isPinned)
        case .excludingPinned:
            candidates = candidates.filter { !$0.isPinned }
        }

        if let trimmedQuery = searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedQuery.isEmpty {
            candidates = candidates.filter { Self.matches($0, query: trimmedQuery) }
        }

        return candidates.sorted {
            NoteSorting.isOrderedBefore($0, $1, criterion: criterion, direction: direction)
        }
    }

    /// Vrai si `note` correspond a `query` selon la regle de recherche de la spec E3 :
    /// titre toujours cherchable, contenu (`plainText`) cherchable seulement si la note
    /// n'est pas verrouillee.
    private static func matches(_ note: Note, query: String) -> Bool {
        if note.title.localizedStandardContains(query) {
            return true
        }
        guard !note.isLocked else { return false }
        return note.plainText.localizedStandardContains(query)
    }

    /// L'id de `folder` et, recursivement, l'id de tous ses sous-dossiers a n'importe
    /// quelle profondeur. Traversee en memoire (relation `subfolders` deja chargeable
    /// par SwiftData via fault), sans `FetchDescriptor` supplementaire : c'est la meme
    /// approche que `Folder.noteCount`.
    private static func folderAndDescendantIDs(of folder: Folder) -> Set<UUID> {
        var ids: Set<UUID> = [folder.id]
        for subfolder in folder.subfolders ?? [] {
            ids.formUnion(folderAndDescendantIDs(of: subfolder))
        }
        return ids
    }
}

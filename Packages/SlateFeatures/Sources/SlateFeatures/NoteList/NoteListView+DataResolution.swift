import SwiftData
import SlateModel

/// Resolution des donnees de `NoteListView` (requete SwiftData + partitionnement
/// epinglees/reste). Extrait dans son propre fichier pour tenir la limite
/// `file_length` de SwiftLint (`NoteListView.swift` gere deja l'essentiel de la spec
/// E3), meme motif que `NoteListView+ContextMenuActions.swift`.
extension NoteListView {
    /// Resultat d'une resolution de `resolveListData(for:)` : toute la matiere premiere
    /// necessaire a `contentBody`/`listScrollView` pour un rendu, obtenue en **une seule**
    /// requete `NoteListQuery` dans le cas courant (voir la documentation de
    /// `resolveListData(for:)`).
    struct NoteListData {
        let pinnedNotes: [Note]
        let restNotes: [Note]
        let dateGroups: [NoteDateGroup]
        /// Vrai si le dossier contient au moins une note, INDEPENDAMMENT de toute
        /// recherche en cours - distingue "Aucune note" (dossier reellement vide) de
        /// "Aucun resultat" (recherche infructueuse dans un dossier non vide).
        let folderHasAnyNotes: Bool
    }

    /// Resout en **une seule** execution de `NoteListQuery.notes(in:...)` (au lieu des
    /// jusqu'a 5 executions par rendu avant cette correction - voir la note de
    /// `folderContent(_:)`) toute la matiere premiere necessaire a l'affichage : cette
    /// premiere requete recupere TOUTES les notes du dossier (`.all`, epinglees et non
    /// epinglees confondues) deja filtrees par la recherche et triees selon le critere
    /// courant ; epinglees et reste sont ensuite separees EN MEMOIRE par
    /// `Self.partitionByPinned`, qui preserve l'ordre - le resultat est donc rigoureusement
    /// identique (meme contenu, meme ordre, aucune duplication) a l'ancien code, qui
    /// obtenait les deux listes via deux requetes independantes (`.pinnedOnly` puis
    /// `.excludingPinned`) : une note epinglee ne peut apparaitre que dans `pinnedNotes`,
    /// jamais aussi dans `restNotes`/`dateGroups`.
    ///
    /// `folderHasAnyNotes` a besoin d'une information que la requete filtree par la
    /// recherche ne peut pas donner : distinguer un dossier reellement vide d'une
    /// recherche simplement infructueuse dans un dossier non vide. Une seconde requete
    /// (non filtree par la recherche, `NoteListQuery.notes(in:)`) n'est donc executee que
    /// dans le cas precis ou la recherche est non vide ET son resultat est vide - au
    /// maximum 2 requetes dans ce cas, 1 dans tous les autres (recherche vide, ou
    /// recherche non vide avec au moins un resultat, ce qui prouve deja que le dossier
    /// n'est pas vide sans requete supplementaire).
    func resolveListData(for folder: Folder) -> NoteListData {
        let query = NoteListQuery(context: modelContext)
        let searchQuery = trimmedSearchText.isEmpty ? nil : trimmedSearchText

        let allNotes = (try? query.notes(
            in: folder,
            pinned: .all,
            matching: searchQuery,
            sortedBy: sortCriterion,
            direction: sortDirection
        )) ?? []

        let (pinnedNotes, restNotes) = Self.partitionByPinned(allNotes)

        let folderHasAnyNotes: Bool
        if searchQuery == nil {
            folderHasAnyNotes = !allNotes.isEmpty
        } else if !allNotes.isEmpty {
            folderHasAnyNotes = true
        } else {
            let unfilteredNotes = (try? query.notes(in: folder)) ?? []
            folderHasAnyNotes = !unfilteredNotes.isEmpty
        }

        let dateGroups = NoteDateGrouper.group(notes: restNotes, referenceDate: referenceDate)

        return NoteListData(
            pinnedNotes: pinnedNotes,
            restNotes: restNotes,
            dateGroups: dateGroups,
            folderHasAnyNotes: folderHasAnyNotes
        )
    }

    /// Separe `notes` (deja triees par l'appelant, voir `NoteListQuery`) en notes
    /// epinglees et notes restantes, en preservant STRICTEMENT l'ordre relatif d'entree
    /// dans chacun des deux groupes, sans perdre ni dupliquer aucune note.
    ///
    /// Extraite en fonction pure et `static` (aucune dependance a `self`) precisement
    /// pour etre testable sans construire de vue SwiftUI ni de `ModelContext` - voir
    /// `NoteListViewLogicTests`.
    ///
    /// Pourquoi ce partitionnement produit un resultat identique a deux requetes triees
    /// independamment (l'ancien comportement, un tri via `.pinnedOnly` puis un tri via
    /// `.excludingPinned`) : `notes` est deja totalement ordonnee par le comparateur de
    /// tri choisi (`NoteSorting.isOrderedBefore`, applique par `NoteListQuery`). Filtrer
    /// un sous-ensemble d'une sequence totalement ordonnee sans reordonner ses elements
    /// produit exactement la meme sequence que si ce sous-ensemble avait ete trie seul
    /// avec le meme comparateur - un comparateur total est, par definition, coherent avec
    /// lui-meme sur n'importe quel sous-ensemble.
    static func partitionByPinned(_ notes: [Note]) -> (pinnedNotes: [Note], restNotes: [Note]) {
        var pinnedNotes: [Note] = []
        var restNotes: [Note] = []
        for note in notes {
            if note.isPinned {
                pinnedNotes.append(note)
            } else {
                restNotes.append(note)
            }
        }
        return (pinnedNotes, restNotes)
    }
}

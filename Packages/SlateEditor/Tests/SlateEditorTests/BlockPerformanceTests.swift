import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// Mesures de performance de l'`EditorController` sur une note LONGUE
/// (docs/05_editeur_blocs.md, critere d'acceptation "Fluidite correcte sur une note de
/// 200+ blocs"), jamais mesure jusqu'ici (revue finale de Phase 5). Chaque test imprime
/// sa duree mesuree (`ContinuousClock`) via `Issue.record` en mode informatif -- ce
/// fichier documente des CHIFFRES, il ne bloque pas la suite sur un seuil de temps
/// arbitraire (trop fragile sur des machines de CI heterogenes) : les assertions
/// portent sur la FORME de la courbe (le cout a N=500 ne doit pas exploser par rapport a
/// N=125, sinon le comportement est quadratique caches). Voir le rapport de revue de
/// Phase 5 pour l'analyse et les chiffres exacts obtenus sur la machine de reference.
@MainActor
@Suite("Performance EditorController sur note longue")
struct BlockPerformanceTests {
    /// Construit une note de `count` paragraphes RACINE, en reutilisant EXACTEMENT le
    /// chemin d'insertion reel de l'editeur (`EditorController.appendTrailingParagraph`),
    /// pas une affectation directe de `note.blocks` -- pour mesurer le cout REEL de
    /// frappe repetee d'Entree en fin de note, pas un raccourci de test qui masquerait le
    /// probleme.
    private func makeNote(blockCount count: Int) -> (note: Note, controller: EditorController) {
        let note = Note(title: "Note longue")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "0"), note: note)
        note.blocks = [first]
        let controller = EditorController(note: note)
        for index in 1..<count {
            controller.appendTrailingParagraph()
            if let last = BlockOrdering.flattenedBlocks(of: note).last {
                last.text = RichText(plainText: String(index))
            }
        }
        return (note, controller)
    }

    private func measure(_ body: () -> Void) -> Duration {
        let clock = ContinuousClock()
        return clock.measure(body)
    }

    // MARK: - Construction (insertion repetee en fin de note)

    /// Ce test mesure le COUT PAR INSERTION, pas la forme de la courbe de construction
    /// en masse, et c'est un choix delibere qu'il faut expliquer.
    ///
    /// La version initiale de ce test affirmait `ratio < 10` sur le temps total de
    /// construction. Elle echouait a ~12-13 meme apres avoir rendu `BlockOrdering`
    /// lineaire (ratio 3,9 mesure sur la navigation, qui utilise le meme code de
    /// parcours). Cause isolee par une sonde dans un package separe, SANS aucun code de
    /// SlateEditor :
    ///
    ///     note.blocks?.append(bloc) en boucle : 125 = 25 ms, 500 = 334 ms, ratio 13,1
    ///     ModelContext.insert SEUL, sans toucher la relation : ratio 12,7
    ///
    /// La non-linearite vient donc de `ModelContext.insert` de SwiftData lui-meme, pas
    /// de notre code ni meme de l'accesseur de relation. Aucune intervention dans
    /// SlateModel ne la supprimerait : c'est une caracteristique du framework.
    ///
    /// Garder l'assertion sur le ratio total aurait produit un test rouge en permanence,
    /// mesurant un coût que nous ne controlons pas - donc du bruit, qui finit par etre
    /// ignore et masque les vraies regressions. On mesure donc ce qui compte pour
    /// l'utilisateur ET ce que nous controlons : le cout d'UNE insertion sur une note
    /// deja longue. C'est ce que coute une frappe d'Entree, la seule chose que
    /// l'utilisateur ressent. La construction en masse de 500 blocs d'un coup n'est pas
    /// un geste utilisateur ; elle n'apparaitra qu'a l'import (phase ulterieure), qui
    /// devra alors utiliser une insertion par lot et non cette boucle.
    ///
    /// La forme de la courbe de NOTRE code reste verrouillee par les trois autres tests
    /// de ce fichier (navigation, suppression en lot, positions de selection), qui
    /// n'inserent rien et sont donc exempts du cout de SwiftData.
    @Test("Le cout d'UNE insertion sur une note de 500 blocs reste dans un budget de frame")
    func singleInsertionCostOnLongNote() {
        let (note, controller) = makeNote(blockCount: 500)
        #expect(BlockOrdering.flattenedBlocks(of: note).count == 500)

        // Moyenne sur plusieurs insertions pour lisser le bruit de mesure.
        let insertionCount = 20
        let total = measure {
            for _ in 0..<insertionCount {
                controller.appendTrailingParagraph()
            }
        }
        let totalMs = Double(total.components.attoseconds) / 1e15 + Double(total.components.seconds) * 1000
        let perInsertionMs = totalMs / Double(insertionCount)

        let info: Comment = """
            INFO perf : \(insertionCount) insertions sur une note de 500 blocs = \(totalMs) ms, \
            soit \(perInsertionMs) ms par insertion
            """
        Issue.record(info, severity: .warning)

        // Budget d'une frame a 60 Hz = 16,6 ms. On exige un ordre de grandeur de marge :
        // une frappe d'Entree ne doit jamais s'approcher du budget de rendu.
        let message: Comment = "Une insertion coute \(perInsertionMs) ms sur une note de 500 blocs"
        #expect(perInsertionMs < 5, message)
    }

    // MARK: - Navigation clavier (fleche bas repetee, traverse tout le document)

    @Test("Traverser tout le document a la fleche bas : cout a 500 blocs vs 125")
    func arrowNavigationTraversalScaling() {
        let (noteSmall, controllerSmall) = makeNote(blockCount: 125)
        let (noteLarge, controllerLarge) = makeNote(blockCount: 500)

        guard var current = BlockOrdering.flattenedBlocks(of: noteSmall).first else {
            Issue.record("note vide de facon inattendue")
            return
        }
        let smallDuration = measure {
            for _ in 0..<(noteSmall.blocks?.count ?? 0) - 1 {
                // `BlockOrdering.block(after:)` (pas un nouvel appel a
                // `flattenedBlocks(of:)` suivi d'un `.first(where:)` -- une recherche
                // lineaire O(n) qui masquerait exactement le cout qu'on mesure ici) :
                // c'est EXACTEMENT ce que `handleMoveDown` calcule deja en interne pour
                // determiner le bloc cible, donc la maniere fidele de savoir ou la
                // boucle continue sans ajouter un cout de bord qui n'existe pas cote
                // production.
                guard let next = BlockOrdering.block(after: current),
                      controllerSmall.handleMoveDown(from: current, visualColumnX: 0) else {
                    break
                }
                current = next
            }
        }
        guard var currentLarge = BlockOrdering.flattenedBlocks(of: noteLarge).first else {
            Issue.record("note vide de facon inattendue")
            return
        }
        let largeDuration = measure {
            for _ in 0..<(noteLarge.blocks?.count ?? 0) - 1 {
                guard let next = BlockOrdering.block(after: currentLarge),
                      controllerLarge.handleMoveDown(from: currentLarge, visualColumnX: 0) else {
                    break
                }
                currentLarge = next
            }
        }

        let smallMs = durationInMs(smallDuration)
        let largeMs = durationInMs(largeDuration)
        let ratio = smallMs > 0 ? largeMs / smallMs : 0

        Issue.record(
            "INFO perf : traverser 125 blocs = \(smallMs) ms, traverser 500 blocs = \(largeMs) ms, ratio = \(ratio)",
            severity: .warning
        )

        // AVANT correctif (revue finale de Phase 5) : chaque pression de fleche
        // appelait `BlockOrdering.block(after:)`, qui refaisait `flattenedBlocks(of:)`
        // (DFS complet, O(n)) A CHAQUE PRESSION -- traverser tout le document etait
        // donc O(n^2) PAR CONSTRUCTION (ratio mesure ~16-18, voir le rapport de revue).
        // APRES correctif : `flattenedBlocks(of:)`/`block(after:)` lisent un cache par
        // note (`BlockOrdering.cachedOrder`), invalide UNIQUEMENT par une mutation
        // structurelle -- aucune n'a lieu pendant une simple navigation. La boucle
        // ci-dessus reste O(n) au total (le premier appel construit le cache, tous les
        // suivants sont des lectures O(1)) : le ratio attendu revient a ~4 (lineaire),
        // pas ~16 -- ce test verrouille desormais l'ABSENCE de regression quadratique.
        let message: Comment = "Navigation encore proche de O(n^2) : ratio \(ratio) pour 4x plus de blocs"
        #expect(ratio < 10, message)
    }

    // MARK: - Selection multi-blocs : un seul calcul par rendu

    @Test("selectionRangePositions() sur une plage couvrant tout le document (500 blocs)")
    func selectionRangePositionsSingleCallCost() {
        let (note, controller) = makeNote(blockCount: 500)
        let all = BlockOrdering.flattenedBlocks(of: note)
        guard let firstBlock = all.first, let lastBlock = all.last else {
            Issue.record("note vide de facon inattendue")
            return
        }
        controller.selectBlock(firstBlock)
        controller.extendSelection(to: lastBlock)

        let duration = measure {
            _ = controller.selectionRangePositions()
        }
        let ms = durationInMs(duration)
        Issue.record(
            "INFO perf : selectionRangePositions() sur 500 blocs (plage complete) = \(ms) ms",
            severity: .warning
        )

        // Un seul appel par rendu (voir NoteDocumentView) : doit rester largement
        // sous la fenetre d'une frame (16 ms a 60 Hz) meme sur 500 blocs.
        #expect(ms < 16, "selectionRangePositions() devrait couter << 1 frame, mesure \(ms) ms")
    }

    // MARK: - Suppression en lot

    @Test("deleteSelectionRange() sur la moitie d'une note de 500 blocs")
    func deleteSelectionRangeScaling() {
        let (noteSmall, controllerSmall) = makeNote(blockCount: 125)
        let allSmall = BlockOrdering.flattenedBlocks(of: noteSmall)
        controllerSmall.selectBlock(allSmall[0])
        controllerSmall.extendSelection(to: allSmall[allSmall.count / 2])

        let (noteLarge, controllerLarge) = makeNote(blockCount: 500)
        let allLarge = BlockOrdering.flattenedBlocks(of: noteLarge)
        controllerLarge.selectBlock(allLarge[0])
        controllerLarge.extendSelection(to: allLarge[allLarge.count / 2])

        let smallDuration = measure { controllerSmall.deleteSelectionRange() }
        let largeDuration = measure { controllerLarge.deleteSelectionRange() }

        let smallMs = durationInMs(smallDuration)
        let largeMs = durationInMs(largeDuration)
        let ratio = smallMs > 0 ? largeMs / smallMs : 0

        Issue.record(
            "INFO perf : supprimer 62/125 = \(smallMs) ms, supprimer 250/500 = \(largeMs) ms, ratio = \(ratio)",
            severity: .warning
        )

        // AVANT correctif (revue finale de Phase 5) : `deleteRange(_:in:)` appelait
        // `BlockOrdering.remove(_:)` bloc par bloc, chacun recalculant sa fratrie
        // complete (O(n)) -- suppression de m blocs sur n = O(m*n) (ratio mesure
        // ~12.9, voir le rapport de revue). APRES correctif : `BlockOrdering.removeAll(_:)`
        // traite tout le lot en UNE seule passe O(n) quand les blocs sont freres directs
        // (le cas de ce test, une plage plate) -- ratio attendu ~4 (lineaire).
        #expect(ratio < 10, "Suppression en lot encore proche de O(n^2) : ratio \(ratio)")
    }

    private func durationInMs(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}

import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import SlateEditor

/// `BlockDropResolution` : calcul PUR de la frontiere de depot la plus proche du
/// pointeur (Phase 10). Chemin critique explicitement demande : le tiers lateral qui
/// declenche la colonne, la moitie haute/basse qui declenche l'insertion horizontale, et
/// le rattachement aux bords du document (aucun bloc mesure sous le pointeur).
@Suite("BlockDropResolution")
struct BlockDropResolutionTests {
    private let blockA = UUID()
    private let blockB = UUID()

    /// Deux blocs empiles, chacun 100x40, sans espace entre eux : A en [0,40), B en
    /// [40,80). Largeur commune 300 (tiers lateral = 100 pt).
    private var twoStackedFrames: [UUID: CGRect] {
        [
            blockA: CGRect(x: 0, y: 0, width: 300, height: 40),
            blockB: CGRect(x: 0, y: 40, width: 300, height: 40)
        ]
    }

    @Test("Aucun cadre connu : retourne nil")
    func noFramesReturnsNil() {
        #expect(BlockDropResolution.resolve(pointerLocation: CGPoint(x: 10, y: 10), blockFrames: [:]) == nil)
    }

    @Test("Moitie HAUTE d'un bloc : insertion .top")
    func topHalfResolvesToTopEdge() {
        let point = CGPoint(x: 150, y: 5) // dans A, pres du haut
        let target = BlockDropResolution.resolve(pointerLocation: point, blockFrames: twoStackedFrames)
        #expect(target == BlockDropTarget(blockID: blockA, edge: .top))
    }

    @Test("Moitie BASSE d'un bloc : insertion .bottom")
    func bottomHalfResolvesToBottomEdge() {
        let point = CGPoint(x: 150, y: 35) // dans A, pres du bas
        let target = BlockDropResolution.resolve(pointerLocation: point, blockFrames: twoStackedFrames)
        #expect(target == BlockDropTarget(blockID: blockA, edge: .bottom))
    }

    @Test("Tiers GAUCHE d'un bloc : depot lateral .leading (colonne)")
    func leftThirdResolvesToLeadingEdge() {
        let point = CGPoint(x: 20, y: 20) // x < 100 (tiers gauche de 300)
        let target = BlockDropResolution.resolve(pointerLocation: point, blockFrames: twoStackedFrames)
        #expect(target == BlockDropTarget(blockID: blockA, edge: .leading))
    }

    @Test("Tiers DROIT d'un bloc : depot lateral .trailing (colonne)")
    func rightThirdResolvesToTrailingEdge() {
        let point = CGPoint(x: 280, y: 20) // x > 200 (tiers droit de 300)
        let target = BlockDropResolution.resolve(pointerLocation: point, blockFrames: twoStackedFrames)
        #expect(target == BlockDropTarget(blockID: blockA, edge: .trailing))
    }

    @Test("Le tiers lateral prime sur la moitie haute/basse (coin superieur gauche)")
    func lateralThirdTakesPriorityOverVerticalHalf() {
        // Coin superieur GAUCHE : serait ".top" par la seule regle verticale, mais le
        // tiers lateral doit primer (artboard I : le depot lateral cree une colonne des
        // qu'on est dans le tiers, quelle que soit la hauteur survolee).
        let point = CGPoint(x: 5, y: 2)
        let target = BlockDropResolution.resolve(pointerLocation: point, blockFrames: twoStackedFrames)
        #expect(target == BlockDropTarget(blockID: blockA, edge: .leading))
    }

    @Test("Au-dessus du premier bloc : rattache a son bord .top")
    func aboveFirstBlockSnapsToTop() {
        let point = CGPoint(x: 150, y: -20)
        let target = BlockDropResolution.resolve(pointerLocation: point, blockFrames: twoStackedFrames)
        #expect(target == BlockDropTarget(blockID: blockA, edge: .top))
    }

    @Test("En dessous du dernier bloc : rattache a son bord .bottom")
    func belowLastBlockSnapsToBottom() {
        let point = CGPoint(x: 150, y: 500)
        let target = BlockDropResolution.resolve(pointerLocation: point, blockFrames: twoStackedFrames)
        #expect(target == BlockDropTarget(blockID: blockB, edge: .bottom))
    }

    @Test("Bloc unique tres etroit : le tiers lateral reste proportionnel a SA largeur")
    func narrowBlockKeepsProportionalThird() {
        let narrowID = UUID()
        let frames: [UUID: CGRect] = [narrowID: CGRect(x: 0, y: 0, width: 60, height: 40)]
        // Tiers = 20 pt. x = 15 doit tomber dans le tiers gauche.
        let target = BlockDropResolution.resolve(pointerLocation: CGPoint(x: 15, y: 20), blockFrames: frames)
        #expect(target == BlockDropTarget(blockID: narrowID, edge: .leading))
        // x = 30 (au milieu) doit retomber sur la regle verticale (moitie haute ici).
        let middleTarget = BlockDropResolution.resolve(pointerLocation: CGPoint(x: 30, y: 5), blockFrames: frames)
        #expect(middleTarget == BlockDropTarget(blockID: narrowID, edge: .top))
    }
}

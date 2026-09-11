import SwiftUI
import Testing
@testable import SlateUI

/// Verifie par calcul la formule pure de `EditorColumnBreakout.resolvedWidth(targetWidth:
/// availableWidth:)` (Phase 10, extraite de `SlateColumnBreakoutModifier` pour rester
/// testable sans hierarchie de vues -- voir `EditorColumnBreakout.swift`).
@Suite("EditorColumnBreakout - largeur de debord")
struct EditorColumnBreakoutTests {
    private let standardRowWidth = SlateGeometry.editorMaxContentWidth + SlateGeometry.editorGutter

    @Test("Panneau a exactement la largeur standard : le debord reste capé a la largeur de colonne")
    func standardPanelCapsToColumnWidth() {
        let width = EditorColumnBreakout.resolvedWidth(
            targetWidth: SlateGeometry.mediaOverflowWidth, availableWidth: standardRowWidth
        )
        #expect(width == SlateGeometry.editorMaxContentWidth)
    }

    @Test("Panneau plus etroit que la largeur standard : jamais en dessous de editorMaxContentWidth")
    func narrowerPanelNeverGoesBelowStandardColumnWidth() {
        let width = EditorColumnBreakout.resolvedWidth(targetWidth: nil, availableWidth: 600)
        #expect(width == SlateGeometry.editorMaxContentWidth)
    }

    @Test("Panneau tres large : le palier 960 pt est atteint exactement, sans etre rogne")
    func wideEnoughPanelReachesExactTargetWidth() {
        let width = EditorColumnBreakout.resolvedWidth(
            targetWidth: SlateGeometry.mediaOverflowWidth, availableWidth: 1500
        )
        #expect(width == SlateGeometry.mediaOverflowWidth)
    }

    @Test("Panneau large mais pas assez pour 960 pt : le debord est rogne a ce que le panneau offre")
    func insufficientlyWidePanelCapsBelowTarget() {
        let width = EditorColumnBreakout.resolvedWidth(
            targetWidth: SlateGeometry.mediaOverflowWidth, availableWidth: 1200
        )
        #expect(width < SlateGeometry.mediaOverflowWidth)
        #expect(width > SlateGeometry.editorMaxContentWidth)
    }

    @Test("Pleine largeur (targetWidth nil) suit la largeur reellement disponible du panneau")
    func fullWidthFollowsAvailablePanelWidth() {
        let narrow = EditorColumnBreakout.resolvedWidth(targetWidth: nil, availableWidth: 1200)
        let wide = EditorColumnBreakout.resolvedWidth(targetWidth: nil, availableWidth: 1500)
        #expect(wide > narrow)
    }
}

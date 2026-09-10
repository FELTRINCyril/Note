import CoreGraphics
import Testing

@testable import SlateEditor

/// `FormatBarPositioning` : calcul PUR du cadre de la barre de formatage flottante --
/// aucune fenetre necessaire (voir sa documentation de tete de fichier).
@Suite("FormatBarPositioning")
struct FormatBarPositioningTests {
    private let barSize = CGSize(width: 280, height: 36)
    private let offset: CGFloat = 8

    @Test("La barre s'ancre AU-DESSUS de la selection quand la place est suffisante")
    func placesAboveWhenRoomAvailable() {
        let selectionRect = CGRect(x: 100, y: 200, width: 60, height: 20)

        let frame = FormatBarPositioning.frame(
            forSelectionRect: selectionRect, barSize: barSize, offset: offset, visibleTopY: 0
        )

        #expect(frame.maxY == selectionRect.minY - offset)
        #expect(frame.midX == selectionRect.midX)
        #expect(frame.width == barSize.width)
        #expect(frame.height == barSize.height)
    }

    @Test("La barre bascule EN DESSOUS quand se placer au-dessus deborderait de visibleTopY")
    func placesBelowWhenNotEnoughRoomAbove() {
        // Selection tout en haut de la zone visible : au-dessus (offset + hauteur =
        // 44 pt) deborderait largement au-dela de `visibleTopY`.
        let selectionRect = CGRect(x: 100, y: 10, width: 60, height: 20)

        let frame = FormatBarPositioning.frame(
            forSelectionRect: selectionRect, barSize: barSize, offset: offset, visibleTopY: 0
        )

        #expect(frame.minY == selectionRect.maxY + offset)
        #expect(frame.midX == selectionRect.midX)
    }

    @Test("Cas limite : la barre reste AU-DESSUS si elle affleure exactement visibleTopY")
    func placesAboveWhenExactlyAtLimit() {
        // aboveY = selectionRect.minY - offset - barSize.height = 44 - 8 - 36 = 0.
        let selectionRect = CGRect(x: 0, y: 44, width: 60, height: 20)

        let frame = FormatBarPositioning.frame(
            forSelectionRect: selectionRect, barSize: barSize, offset: offset, visibleTopY: 0
        )

        #expect(frame.minY == 0)
        #expect(frame.maxY == selectionRect.minY - offset)
    }

    @Test("La barre est centree horizontalement sur la selection dans les deux cas")
    func centersHorizontallyInBothCases() {
        let above = FormatBarPositioning.frame(
            forSelectionRect: CGRect(x: 100, y: 200, width: 60, height: 20),
            barSize: barSize, offset: offset, visibleTopY: 0
        )
        let below = FormatBarPositioning.frame(
            forSelectionRect: CGRect(x: 100, y: 10, width: 60, height: 20),
            barSize: barSize, offset: offset, visibleTopY: 0
        )

        #expect(above.midX == 130)
        #expect(below.midX == 130)
    }
}

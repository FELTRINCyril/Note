import Foundation
import Testing

@testable import SlateEditor

/// `BlockSelectionRange` : type PUR (deux `UUID`), aucune dependance a `SlateModel`.
@Suite("BlockSelectionRange")
struct BlockSelectionRangeTests {
    @Test("init(single:) confond ancre et tete")
    func singleInitConfoundsAnchorAndFocus() {
        let id = UUID()

        let range = BlockSelectionRange(single: id)

        #expect(range.anchorBlockID == id)
        #expect(range.focusBlockID == id)
        #expect(range.isSingleBlock == true)
    }

    @Test("isSingleBlock est faux quand ancre et tete different")
    func isSingleBlockIsFalseWhenAnchorAndFocusDiffer() {
        let range = BlockSelectionRange(anchorBlockID: UUID(), focusBlockID: UUID())

        #expect(range.isSingleBlock == false)
    }
}

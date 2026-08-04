import Foundation
import SwiftUI

/// Cadre de CHAQUE bloc rendu, dans la `coordinateSpace` nommee partagee par
/// `NoteDocumentView` (`NoteDocumentView.blockListCoordinateSpace`) -- alimente par
/// `BlockTreeView` via un `GeometryReader` en arriere-plan de chaque `BlockContainer`,
/// consomme par `NoteDocumentView.onPreferenceChange(_:)` qui le repousse vers
/// `EditorController.updateBlockFrames(_:)` (sous-etape 5.6, glisser de selection --
/// voir sa documentation pour pourquoi ce dictionnaire est necessaire : resoudre "quel
/// bloc est sous le pointeur" pendant un glisser qui sort du bloc ou il a commence).
///
/// Une seule cle par identifiant de bloc : `reduce(value:nextValue:)` ecrase avec la
/// valeur la plus RECENTE en cas de collision (ne devrait jamais arriver, chaque bloc
/// n'apparait qu'une fois dans l'arbre) plutot que de fusionner -- un cadre de bloc n'a
/// pas de sens a "additionner".
struct BlockFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, next in next }
    }
}

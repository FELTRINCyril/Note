import AppKit
import SlateModel
import SwiftUI
import UniformTypeIdentifiers

/// Point d'attache SwiftUI unique du glisser-depose de blocs ET de fichiers (Phase 10) :
/// `View.onDrop(of:delegate:)`, protocole `DropDelegate` LEGACY plutot que le nouveau
/// `dropDestination(for:action:isTargeted:)` -- voir la documentation de tete
/// d'`EditorController+DragDrop.swift` pour le pourquoi (position du pointeur EN
/// CONTINU pendant le survol, indispensable a la ligne d'insertion qui suit le
/// pointeur).
///
/// Attache par `NoteDocumentView` UNE SEULE FOIS, sur le MEME conteneur qui porte
/// `coordinateSpace(name: NoteDocumentView.blockListCoordinateSpace)` : `info.location`
/// est alors DEJA dans cette `coordinateSpace`, exactement celle attendue par
/// `EditorController.blockFrames`/`BlockDropResolution` -- aucune conversion
/// supplementaire necessaire.
struct BlockAndFileDropDelegate: DropDelegate {
    let editorController: EditorController

    /// Types acceptes : `.plainText` porte l'UUID du bloc glisse (`BlockHandle.
    /// draggable(_:)`, `SlateUI`, session `String`/`Transferable`) ; `.fileURL` porte un
    /// ou plusieurs fichiers glisses depuis le Finder (Phase 9, report Phase 10).
    static let acceptedTypes: [UTType] = [.plainText, .fileURL]

    func dropEntered(info: DropInfo) {
        guard info.hasItemsConforming(to: [.plainText]) else { return }
        guard let provider = info.itemProviders(for: [.plainText]).first else { return }
        provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let string = reading as? NSString, let uuid = UUID(uuidString: string as String) else { return }
            Task { @MainActor in
                editorController.beginBlockDrag(byID: uuid)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        editorController.updateBlockDragTarget(pointerLocation: info.location)
        if info.hasItemsConforming(to: [.fileURL]) {
            editorController.updateDragFileCount(info.itemProviders(for: [.fileURL]).count)
        }
        return DropProposal(operation: .move)
    }

    /// "Sortie de survol immediate sans animation" (docs/10, tache 3) : voir
    /// `EditorController.endBlockDrag()`.
    func dropExited(info: DropInfo) {
        editorController.endBlockDrag()
    }

    func performDrop(info: DropInfo) -> Bool {
        let location = info.location
        if info.hasItemsConforming(to: [.fileURL]) {
            let providers = info.itemProviders(for: [.fileURL])
            return editorController.performFileDrop(providers: providers, pointerLocation: location)
        }
        if info.hasItemsConforming(to: [.plainText]) {
            return editorController.performBlockDrop(pointerLocation: location)
        }
        return false
    }
}

import CoreGraphics
import Foundation
import SwiftUI

/// Cible de depot resolue a partir de la position du pointeur pendant un glisser de
/// bloc OU de fichier (Phase 10, docs/10_dragdrop_colonnes.md, artboards I et C de P2).
/// `blockID` designe le bloc SURVOLE, `edge` la frontiere concernee : `.top`/`.bottom`
/// pour une insertion HORIZONTALE entre deux blocs (reordonnancement), `.leading`/
/// `.trailing` pour un depot LATERAL sur le tiers gauche/droit d'un bloc (creation de
/// colonne, artboard I "Depot lateral -> colonne").
public struct BlockDropTarget: Equatable, Sendable {
    public let blockID: UUID
    public let edge: Edge

    public init(blockID: UUID, edge: Edge) {
        self.blockID = blockID
        self.edge = edge
    }
}

/// Calcul PUR (aucune dependance AppKit, aucun `Block`) de la frontiere de depot la plus
/// proche du pointeur, a partir des cadres de bloc DEJA mesures
/// (`EditorController.blockFrames`, meme `coordinateSpace` que
/// `NoteDocumentView.blockListCoordinateSpace`). Reutilise EXACTEMENT le meme schema que
/// `EditorController.blockID(at:)` (`EditorController+Selection.swift`, sous-etape 5.6)
/// pour resoudre "quel bloc est sous le pointeur" -- aucune nouvelle `PreferenceKey`
/// introduite ici, comme demande par docs/10.
public enum BlockDropResolution {
    /// Largeur du tiers lateral (gauche/droit) d'un bloc qui declenche un depot LATERAL
    /// plutot qu'une insertion horizontale (docs/10, artboard I). Une FRACTION de la
    /// largeur du cadre, pas une valeur fixe en points : un bloc etroit (deja une
    /// colonne existante) garde un tiers lateral proportionnel a sa propre largeur.
    static let lateralThirdFraction: CGFloat = 1.0 / 3.0

    /// Resout la cible de depot pour `pointerLocation` (meme `coordinateSpace` que
    /// `blockFrames`). `nil` UNIQUEMENT si aucun cadre n'est connu (note sans aucun bloc
    /// mesure) -- un pointeur au-dessus du premier bloc ou en dessous du dernier reste
    /// actionnable, rattache a l'extremite la plus proche (glisser jusqu'au bord du
    /// document doit continuer de fonctionner).
    public static func resolve(pointerLocation: CGPoint, blockFrames: [UUID: CGRect]) -> BlockDropTarget? {
        guard !blockFrames.isEmpty else { return nil }

        if let hovered = blockFrames.first(where: { entry in
            entry.value.minY <= pointerLocation.y && pointerLocation.y < entry.value.maxY
        }) {
            return target(in: hovered.value, blockID: hovered.key, pointerLocation: pointerLocation)
        }

        let sortedByTop = blockFrames.sorted { $0.value.minY < $1.value.minY }
        guard let first = sortedByTop.first, let last = sortedByTop.last else { return nil }
        if pointerLocation.y < first.value.minY {
            return BlockDropTarget(blockID: first.key, edge: .top)
        }
        return BlockDropTarget(blockID: last.key, edge: .bottom)
    }

    /// Frontiere au sein d'un bloc DEJA identifie comme survole verticalement : tiers
    /// gauche/droit -> depot lateral (colonne), sinon moitie haute/basse -> insertion
    /// horizontale avant/apres ce bloc.
    private static func target(in frame: CGRect, blockID: UUID, pointerLocation: CGPoint) -> BlockDropTarget {
        let lateralWidth = frame.width * lateralThirdFraction
        if pointerLocation.x < frame.minX + lateralWidth {
            return BlockDropTarget(blockID: blockID, edge: .leading)
        }
        if pointerLocation.x > frame.maxX - lateralWidth {
            return BlockDropTarget(blockID: blockID, edge: .trailing)
        }
        let verticalMidpoint = frame.minY + frame.height / 2
        return BlockDropTarget(blockID: blockID, edge: pointerLocation.y < verticalMidpoint ? .top : .bottom)
    }
}

import CoreGraphics
import Foundation

/// Ou placer le caret apres une operation de cycle de vie de bloc (docs/05_editeur_blocs.md,
/// sous-etape 5.3). Type PUR (aucune dependance AppKit) : `BlockLifecycle`/
/// `EditorController` le PRODUISENT sans jamais toucher a un `NSTextView` ; seule la
/// couche `RichTextEditingTextView`/`RichTextBlockView.Coordinator` (la seule a
/// connaitre AppKit) le CONSOMME pour positionner reellement le curseur. C'est cette
/// separation qui rend `EditorController` testable sans AppKit -- voir le rapport de
/// livraison de la sous-etape.
public struct EditorCaretRequest: Equatable, Sendable {
    /// Position visee au sein du bloc `blockID`.
    public enum Placement: Equatable, Sendable {
        /// Offset de caracteres exact (ex: jointure d'une fusion, debut d'un bloc
        /// nouvellement scinde).
        case offset(Int)
        /// Fin du contenu du bloc (ex: "Entree" pour rentrer en edition d'un bloc
        /// selectionne -- spec E4 : "Echap sort de l'edition ... Entree y rentre").
        case end
        /// Conserve la colonne visuelle `x` (coordonnees LOCALES du `NSTextView`
        /// d'origine -- portables d'un bloc a l'autre puisque tous partagent le meme
        /// `textContainerInset = .zero` et la meme largeur de colonne, voir
        /// `RichTextEditingTextView`), en atterrissant sur le bord haut ou bas du bloc
        /// cible (spec E4, fleches haut/bas : "conservent la colonne visuelle"). Traduit
        /// en position de caractere par la geometrie REELLE du layout
        /// (`NSTextView.characterIndexForInsertion(at:)`), jamais par un simple offset
        /// de caracteres -- exigence explicite de la spec.
        case visualColumn(x: CGFloat, edge: VerticalEdge)
    }

    /// Bord vertical du bloc cible vise par `.visualColumn`.
    public enum VerticalEdge: Equatable, Sendable {
        case top
        case bottom
    }

    public let blockID: UUID
    public let placement: Placement

    public init(blockID: UUID, placement: Placement) {
        self.blockID = blockID
        self.placement = placement
    }
}

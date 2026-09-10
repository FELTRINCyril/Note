import CoreGraphics

/// Calcul PUR (aucune dependance SwiftUI/AppKit) du cadre de la barre de formatage
/// flottante (docs/07_typographie_formatage.md, artboard P1 A) : ancree 8 pt au-dessus
/// de la plage selectionnee et centree dessus, sauf si la fenetre est trop haut placee
/// pour l'accueillir -- elle bascule alors EN DESSOUS. Type testable sans fenetre reelle
/// (`FormatBarPositioningTests`), consomme par `FormatBarOverlay`.
enum FormatBarPositioning {
    /// - Parameters:
    ///   - selectionRect: rectangle de la selection de texte, dans le meme repere que
    ///     `visibleTopY` (la `coordinateSpace` nommee partagee de l'editeur -- voir
    ///     `EditorController.blockFrames`/`inlineSelection`).
    ///   - barSize: dimensions de la barre (largeur mesuree par SwiftUI, hauteur fixe
    ///     `SlateGeometry.formatBarHeight`).
    ///   - offset: decalage vertical entre la barre et la plage (`SlateGeometry.formatBarOffset`).
    ///   - visibleTopY: ordonnee la plus haute encore visible dans ce repere (typiquement
    ///     0, ou l'ordonnee du haut du `ScrollView` si elle est connue) : la barre bascule
    ///     EN DESSOUS de la plage des que se placer au-dessus la ferait deborder au-dela
    ///     de cette limite.
    static func frame(
        forSelectionRect selectionRect: CGRect,
        barSize: CGSize,
        offset: CGFloat,
        visibleTopY: CGFloat
    ) -> CGRect {
        let centeredX = selectionRect.midX - barSize.width / 2
        let aboveY = selectionRect.minY - offset - barSize.height
        if aboveY >= visibleTopY {
            return CGRect(x: centeredX, y: aboveY, width: barSize.width, height: barSize.height)
        }
        let belowY = selectionRect.maxY + offset
        return CGRect(x: centeredX, y: belowY, width: barSize.width, height: barSize.height)
    }
}

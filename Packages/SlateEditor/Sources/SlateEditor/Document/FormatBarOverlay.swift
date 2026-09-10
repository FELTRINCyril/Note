import SlateModel
import SlateUI
import SwiftUI

/// Overlay de la barre de formatage flottante (docs/07_typographie_formatage.md,
/// artboard P1 A) : positionne `FormatBarView` par CALCUL au-dessus (ou en dessous, si
/// la fenetre est trop haut placee -- voir `FormatBarPositioning`) de la selection de
/// texte courante, dans la MEME `coordinateSpace` nommee que `SlashMenuOverlay`
/// (`EditorController.blockFrames`/`inlineSelection`).
///
/// ## Pourquoi un overlay et pas un `.popover` (meme raisonnement que `SlashMenuOverlay`)
/// Contrairement aux popovers de couleur/lien (actions PONCTUELLES au clic, voir
/// `FormatColorPopoverView`/`LinkEditorPopoverView`), la barre elle-meme doit rester
/// visible et REAGIR en continu tant que la selection de texte existe -- un `.popover`
/// standard se fermerait/se repositionnerait de facon opaque a chaque frappe qui
/// modifie la selection, et prendrait la fenetre cle au moment de son ouverture (meme
/// argument que `SlashMenuOverlay`, voir sa documentation de tete).
struct FormatBarOverlay: View {
    let block: Block
    let editorController: EditorController
    let selection: EditorInlineSelection

    /// Taille REELLE de la barre, mesuree par SwiftUI (voir `FormatBarSizePreferenceKey`)
    /// -- une valeur de repli raisonnable est utilisee tant qu'elle n'a pas encore ete
    /// mesuree (premier rendu), pour eviter un cadre nul qui ferait clignoter la barre.
    @State private var barSize = CGSize(width: 280, height: SlateGeometry.formatBarHeight)

    var body: some View {
        if let rect = selection.rect {
            let frame = FormatBarPositioning.frame(
                forSelectionRect: rect,
                barSize: barSize,
                offset: SlateGeometry.formatBarOffset,
                visibleTopY: 0
            )
            FormatBarView(block: block, editorController: editorController, range: selection.range)
                .fixedSize()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: FormatBarSizePreferenceKey.self, value: proxy.size)
                    }
                )
                .onPreferenceChange(FormatBarSizePreferenceKey.self) { barSize = $0 }
                .position(x: frame.midX, y: frame.midY)
        }
    }
}

private struct FormatBarSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize { CGSize(width: 280, height: SlateGeometry.formatBarHeight) }

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        guard next != .zero else { return }
        value = next
    }
}

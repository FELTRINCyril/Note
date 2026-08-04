import Foundation
import SlateUI

/// Style typographique et hauteur de ligne d'un titre, pour un niveau 1 a 6.
///
/// Les niveaux 1 a 3 reutilisent les paliers generaux existants de `SlateFont`
/// (`titleNote`, `titleSecondary`, `subtitle`), choix fait avant la spec de titres
/// dediee et inchange ici (hors perimetre du comblement de gap de Phase 5). Les niveaux
/// 4 a 6 utilisaient `SlateFont.bodyEmphasis` (15 Semibold) en attendant : ils
/// restaient visuellement DISTINCTS d'un paragraphe (gras) mais pas les uns des autres.
/// `SlateFont.h4`/`h5`/`h6` (design/tokens.md §9), ajoutes en Phase 5, comblent ce gap
/// signale par l'agent 5.1.
enum HeadingStyle {
    static func font(forLevel level: Int) -> SlateTextStyle {
        switch level {
        case 1: SlateFont.titleNote
        case 2: SlateFont.titleSecondary
        case 3: SlateFont.subtitle
        case 4: SlateFont.h4
        case 5: SlateFont.h5
        default: SlateFont.h6
        }
    }

    /// Hauteur de la premiere ligne du contenu, pour centrer `BlockHandle` dessus (voir
    /// `BlockContainer.firstLineHeight`). Applique le meme multiplicateur d'interligne
    /// que le corps de texte (`editorParagraphLineHeight`) a la taille du titre.
    static func firstLineHeight(forLevel level: Int) -> CGFloat {
        font(forLevel: level).size * SlateGeometry.editorParagraphLineHeight
    }
}

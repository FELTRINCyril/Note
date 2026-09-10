import Foundation
import SlateUI

/// Style typographique et hauteur de ligne d'un titre, pour un niveau 1 a 6.
///
/// Les niveaux 1 a 3 reutilisaient les paliers generaux de `SlateFont` (`titleNote`,
/// `titleSecondary`, `subtitle`) faute de mieux -- ces trois tokens sont en realite
/// destines au TITRE DE NOTE (`NoteHeaderView`), pas a un H1/H2/H3 de bloc dans le corps
/// du document, et ne correspondaient pas a l'echelle H1-H6 de l'artboard
/// `design/_design_complet/Slate P1 - Formatage & blocs.dc.html` (section D). Corrige
/// en Phase 7 avec `SlateFont.h1`/`h2`/`h3` (design/tokens.md §9), sur le meme modele que
/// `h4`/`h5`/`h6` deja combles en Phase 5.
enum HeadingStyle {
    static func font(forLevel level: Int) -> SlateTextStyle {
        switch level {
        case 1: SlateFont.h1
        case 2: SlateFont.h2
        case 3: SlateFont.h3
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

import Foundation
import SlateUI

/// Style typographique et hauteur de ligne d'un titre, pour un niveau 1 a 6.
///
/// GAP DE TOKENS SIGNALE (voir rapport de livraison 5.1) : `SlateFont` (SlateUI) ne
/// porte que 3 paliers de titre (`titleNote` 28, `titleSecondary` 22, `subtitle` 17),
/// pas 6. En attendant un token dedie par `design-integrator`, les niveaux 4 a 6
/// retombent tous sur `SlateFont.bodyEmphasis` (15 Semibold) : ils restent
/// visuellement DISTINCTS d'un paragraphe (gras) mais pas les uns des autres. Aucune
/// taille brute n'est inventee ici : uniquement des tokens `SlateFont` existants.
enum HeadingStyle {
    static func font(forLevel level: Int) -> SlateTextStyle {
        switch level {
        case 1: SlateFont.titleNote
        case 2: SlateFont.titleSecondary
        case 3: SlateFont.subtitle
        default: SlateFont.bodyEmphasis
        }
    }

    /// Hauteur de la premiere ligne du contenu, pour centrer `BlockHandle` dessus (voir
    /// `BlockContainer.firstLineHeight`). Applique le meme multiplicateur d'interligne
    /// que le corps de texte (`editorParagraphLineHeight`) a la taille du titre.
    static func firstLineHeight(forLevel level: Int) -> CGFloat {
        font(forLevel: level).size * SlateGeometry.editorParagraphLineHeight
    }
}

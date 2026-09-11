import SwiftUI

/// Marqueur d'un item de liste (design/tokens.md §16, artboard G) : puces cycliques par
/// niveau (rond, chevron, carre) ou numerotation cyclique (chiffres, lettres, romains),
/// renumerotee automatiquement par l'appelant (`SlateEditor`, qui connait la position
/// reelle de l'item dans sa liste).
public enum SlateListMarker: Equatable, Sendable {
    /// Liste a puces. `level` determine la forme (0 = rond, 1 = chevron, 2+ = carre,
    /// cycle tous les 3 niveaux).
    case bullet(level: Int)
    /// Liste numerotee. `index` demarre a 1. `level` determine le style (0 = chiffres,
    /// 1 = lettres, 2+ = chiffres romains minuscules, cycle tous les 3 niveaux).
    case ordered(index: Int, level: Int)

    /// Niveau d'imbrication, pour l'indentation (`SlateGeometry.editorListIndentStep`).
    public var level: Int {
        switch self {
        case let .bullet(level): level
        case let .ordered(_, level): level
        }
    }

    /// Texte affiche dans la colonne de marqueur.
    public var text: String {
        switch self {
        case let .bullet(level):
            Self.bulletGlyphs[level % Self.bulletGlyphs.count]
        case let .ordered(index, level):
            switch level % 3 {
            case 0: "\(index)."
            case 1: "\(Self.letter(for: index))."
            default: "\(Self.roman(for: index))."
            }
        }
    }

    /// Le marqueur est-il numerote (alignement a droite) ou une puce (alignement centre) ?
    public var isOrdered: Bool {
        if case .ordered = self { return true }
        return false
    }

    // MARK: - Glyphes de puces (echappes en \u{...} : la ponctuation ASCII du projet
    // interdit une puce unicode LITTERALE dans le code source, pas sa production a
    // l'execution).
    private static let bulletGlyphs = ["\u{2022}", "\u{25B8}", "\u{25AA}"]

    /// Lettre minuscule cyclique (a, b, c... puis a nouveau a apres z), 1-indexee.
    private static func letter(for index: Int) -> Character {
        let alphabetSize = 26
        let zeroBased = (index - 1) % alphabetSize
        let scalarValue = 97 + zeroBased
        guard let scalar = Unicode.Scalar(scalarValue) else { return "a" }
        return Character(scalar)
    }

    /// Chiffres romains minuscules, valides jusqu'a la plage usuelle d'une liste (< 4000).
    private static func roman(for index: Int) -> String {
        let table: [(Int, String)] = [
            (1000, "m"), (900, "cm"), (500, "d"), (400, "cd"),
            (100, "c"), (90, "xc"), (50, "l"), (40, "xl"),
            (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")
        ]
        var remaining = index
        var result = ""
        for (value, symbol) in table {
            while remaining >= value {
                result += symbol
                remaining -= value
            }
        }
        return result
    }
}

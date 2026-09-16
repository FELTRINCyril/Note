import SlateModel
import SlateUI

/// Traduction entre `DatabaseColumnCalculation` (moteur, `SlateModel`) et
/// `SlateDatabaseColumnCalculation` (menu affiche, `SlateUI`) : les deux enumerent le
/// meme jeu d'operations sous deux noms distincts (`countFilled`/`empty` vs `filled`/
/// `empty`...), voir la documentation de tete de `SlateDatabaseColumnCalculation`.
extension SlateDatabaseColumnCalculation {
    var engineCalculation: DatabaseColumnCalculation {
        switch self {
        case .none: .none
        case .count: .count
        case .sum: .sum
        case .average: .average
        case .min: .min
        case .max: .max
        case .empty: .countEmpty
        case .filled: .countFilled
        case .percentFilled: .percentFilled
        }
    }
}

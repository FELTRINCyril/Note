import SwiftUI

/// Logique PURE de repartition des largeurs d'un `ColumnsBlockView` (design/tokens.md
/// §16, artboard J : "Les largeurs sont memorisees en fractions, pas en points, pour
/// survivre au redimensionnement de la fenetre"). Isolee de la vue pour rester
/// testable sans dependance au moteur de layout SwiftUI, meme motif que
/// `WCAGContrast`/`SlateBlockSelection` (calcul pur, teste par calcul).
public enum ColumnFractions {
    /// Normalise une liste de fractions pour qu'elle somme exactement a 1. Repartit
    /// EQUITABLEMENT si la somme d'entree est nulle, negative ou non finie (donnees
    /// corrompues/valeur initiale invalide) plutot que de produire un partage
    /// incoherent.
    public static func normalized(_ fractions: [CGFloat]) -> [CGFloat] {
        guard !fractions.isEmpty else { return [] }
        let sum = fractions.reduce(0, +)
        guard sum > 0, sum.isFinite else {
            return Array(repeating: 1 / CGFloat(fractions.count), count: fractions.count)
        }
        return fractions.map { $0 / sum }
    }

    /// Largeur en points de la colonne `index`, pour une largeur totale disponible
    /// donnee (le `column.gap` entre colonnes -- `SlateGeometry.columnGap` -- est
    /// deduit du total avant repartition). Jamais sous `columnMinWidth`, meme si la
    /// fraction demandee est plus petite : artboard J, "en dessous, la colonne ne peut
    /// plus retrecir".
    public static func width(for fractions: [CGFloat], at index: Int, totalWidth: CGFloat) -> CGFloat {
        guard fractions.indices.contains(index) else { return SlateGeometry.columnMinWidth }
        let gaps = SlateGeometry.columnGap * CGFloat(max(0, fractions.count - 1))
        let usable = max(0, totalWidth - gaps)
        return max(SlateGeometry.columnMinWidth, usable * normalized(fractions)[index])
    }

    /// Nouvelle repartition apres un glissement du separateur entre les colonnes
    /// `index` et `index + 1`, de `delta` points (positif = vers la droite, agrandit
    /// la colonne de gauche). La somme DE LA PAIRE est TOUJOURS preservee exactement
    /// (jamais de derive globale des fractions), et chacune des deux colonnes reste
    /// au-dessus de `columnMinWidth` en clampant `delta` a l'interieur de
    /// `[combined - max, max]` PLUTOT que de clamper chaque cote independamment puis
    /// renormaliser -- cette derniere approche peut reintroduire une violation du
    /// plancher (verifie par `resizingNeverBreaksMinWidth`).
    public static func resizing(
        _ fractions: [CGFloat], at index: Int, byDelta delta: CGFloat, totalWidth: CGFloat
    ) -> [CGFloat] {
        guard fractions.indices.contains(index), fractions.indices.contains(index + 1), totalWidth > 0 else {
            return fractions
        }
        let gaps = SlateGeometry.columnGap * CGFloat(max(0, fractions.count - 1))
        let usable = max(1, totalWidth - gaps)
        var result = normalized(fractions)
        let deltaFraction = delta / usable
        let minFraction = SlateGeometry.columnMinWidth / usable

        let leftIndex = index
        let rightIndex = index + 1
        let combined = result[leftIndex] + result[rightIndex]

        let lowerBound = minFraction
        let upperBound = max(minFraction, combined - minFraction)
        let desiredLeft = result[leftIndex] + deltaFraction
        let clampedLeft = min(max(desiredLeft, lowerBound), upperBound)

        result[leftIndex] = clampedLeft
        result[rightIndex] = combined - clampedLeft
        return result
    }

    /// Redistribue les fractions apres le retrait de la colonne `index` (ex: derniere
    /// colonne videe de ses blocs). La part retiree est partagee EQUITABLEMENT entre
    /// les colonnes restantes -- comportement le moins surprenant en l'absence
    /// d'information sur laquelle des colonnes restantes devrait "heriter" de cet
    /// espace. Retourne `[]` si `index` est hors bornes ou s'il ne reste qu'une seule
    /// colonne (rien a redistribuer : la mise en colonnes elle-meme doit alors etre
    /// dissoute par l'appelant, hors du perimetre de ce calcul).
    public static func removing(_ fractions: [CGFloat], at index: Int) -> [CGFloat] {
        guard fractions.indices.contains(index), fractions.count > 1 else { return [] }
        var remaining = fractions
        remaining.remove(at: index)
        return normalized(remaining)
    }

    /// `true` si la mise en page doit empiler les colonnes dans l'ordre de lecture
    /// (artboard J : "sous 560 pt de largeur de colonne de texte" OU Dynamic Type
    /// `.accessibility1` et au-dela, INDEPENDAMMENT de `availableWidth` -- "a grande
    /// taille de texte, deux colonnes de 120 pt sont illisibles").
    public static func shouldStack(availableWidth: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Bool {
        availableWidth < SlateGeometry.columnStackThreshold || dynamicTypeSize >= .accessibility1
    }
}

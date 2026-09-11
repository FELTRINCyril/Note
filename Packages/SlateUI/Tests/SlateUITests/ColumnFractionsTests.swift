import SwiftUI
import Testing
@testable import SlateUI

/// Verifie par calcul la logique pure de `ColumnFractions` (Phase 10, artboard J de
/// `Slate P1 - Formatage & blocs.dc.html`) : normalisation, largeur minimale de
/// colonne, redistribution au retrait, et seuil d'empilement. Isolee de
/// `ColumnsBlockView` (aucune dependance au moteur de layout SwiftUI), meme motif que
/// les tests de contraste WCAG.
@Suite("ColumnFractions - normalisation")
struct ColumnFractionsNormalizationTests {
    @Test("Une liste deja normalisee est inchangee")
    func alreadyNormalized() {
        let result = ColumnFractions.normalized([0.5, 0.25, 0.25])
        #expect(abs(result.reduce(0, +) - 1) < 0.0001)
        #expect(abs(result[0] - 0.5) < 0.0001)
    }

    @Test("Une liste non normalisee est ramenee a une somme de 1")
    func rescalesToSumOne() {
        let result = ColumnFractions.normalized([2, 1, 1])
        #expect(abs(result.reduce(0, +) - 1) < 0.0001)
        #expect(abs(result[0] - 0.5) < 0.0001)
        #expect(abs(result[1] - 0.25) < 0.0001)
    }

    @Test("Une somme nulle est repartie equitablement, jamais division par zero")
    func zeroSumFallsBackToEqualSplit() {
        let result = ColumnFractions.normalized([0, 0, 0])
        #expect(result.count == 3)
        for fraction in result {
            #expect(abs(fraction - 1.0 / 3.0) < 0.0001)
        }
    }

    @Test("Une somme negative est repartie equitablement")
    func negativeSumFallsBackToEqualSplit() {
        let result = ColumnFractions.normalized([-1, -2])
        #expect(result.count == 2)
        for fraction in result {
            #expect(abs(fraction - 0.5) < 0.0001)
        }
    }

    @Test("Une liste vide reste vide")
    func emptyStaysEmpty() {
        #expect(ColumnFractions.normalized([]).isEmpty)
    }
}

@Suite("ColumnFractions - largeur en points")
struct ColumnFractionsWidthTests {
    @Test("La largeur d'une colonne respecte sa fraction, gap deduit du total")
    func widthMatchesFraction() {
        // 3 colonnes egales, 2 gaps de 24 pt, total 720 -> usable 672 -> 224 chacune.
        let fractions: [CGFloat] = [1.0 / 3, 1.0 / 3, 1.0 / 3]
        let width = ColumnFractions.width(for: fractions, at: 0, totalWidth: 720)
        #expect(abs(width - 224) < 0.5)
    }

    @Test("Une fraction qui demanderait moins que columnMinWidth est plafonnee au minimum")
    func widthNeverBelowMinimum() {
        // Fraction infime -> sans plancher, largeur quasi nulle.
        let fractions: [CGFloat] = [0.001, 0.999]
        let width = ColumnFractions.width(for: fractions, at: 0, totalWidth: 720)
        #expect(width == SlateGeometry.columnMinWidth)
    }

    @Test("Un index hors bornes retombe sur la largeur minimale, jamais un crash")
    func outOfBoundsIndexIsSafe() {
        let width = ColumnFractions.width(for: [0.5, 0.5], at: 5, totalWidth: 720)
        #expect(width == SlateGeometry.columnMinWidth)
    }
}

@Suite("ColumnFractions - redimensionnement au glissement")
struct ColumnFractionsResizingTests {
    @Test("Un glissement vers la droite agrandit la colonne de gauche et retrecit celle de droite")
    func dragRightGrowsLeftColumn() {
        let start: [CGFloat] = [0.5, 0.5]
        let result = ColumnFractions.resizing(start, at: 0, byDelta: 50, totalWidth: 720)
        #expect(result[0] > start[0])
        #expect(result[1] < start[1])
        #expect(abs(result.reduce(0, +) - 1) < 0.0001)
    }

    @Test("La somme de la paire ajustee est preservee (le reste du tableau n'est jamais touche)")
    func resizingPreservesPairSumWithThirdColumn() {
        let start: [CGFloat] = [0.4, 0.3, 0.3]
        let result = ColumnFractions.resizing(start, at: 0, byDelta: 40, totalWidth: 900)
        #expect(abs(result[2] - start[2]) < 0.0001)
        #expect(abs(result.reduce(0, +) - 1) < 0.0001)
    }

    @Test("Un glissement extreme ne fait jamais passer une colonne sous columnMinWidth")
    func resizingNeverBreaksMinWidth() {
        let start: [CGFloat] = [0.5, 0.5]
        let result = ColumnFractions.resizing(start, at: 0, byDelta: 100_000, totalWidth: 720)
        let width = ColumnFractions.width(for: result, at: 1, totalWidth: 720)
        #expect(width >= SlateGeometry.columnMinWidth - 0.5)
    }

    @Test("Un index de separateur hors bornes ne modifie rien")
    func outOfBoundsResizeIsNoOp() {
        let start: [CGFloat] = [0.5, 0.5]
        let result = ColumnFractions.resizing(start, at: 5, byDelta: 50, totalWidth: 720)
        #expect(result == start)
    }
}

@Suite("ColumnFractions - retrait d'une colonne")
struct ColumnFractionsRemovingTests {
    @Test("Le retrait redistribue equitablement la part liberee")
    func removingRedistributesEqually() {
        let result = ColumnFractions.removing([0.5, 0.25, 0.25], at: 0)
        #expect(result.count == 2)
        for fraction in result {
            #expect(abs(fraction - 0.5) < 0.0001)
        }
    }

    @Test("Retirer l'unique colonne restante ne laisse rien a redistribuer")
    func removingLastColumnReturnsEmpty() {
        #expect(ColumnFractions.removing([1.0], at: 0).isEmpty)
    }

    @Test("Un index hors bornes ne modifie rien (liste vide en retour)")
    func removingOutOfBoundsReturnsEmpty() {
        #expect(ColumnFractions.removing([0.5, 0.5], at: 9).isEmpty)
    }
}

@Suite("ColumnFractions - seuil d'empilement (artboard J)")
struct ColumnFractionsStackingTests {
    @Test("Sous 560 pt, les colonnes s'empilent")
    func stacksBelowThreshold() {
        #expect(ColumnFractions.shouldStack(availableWidth: 400, dynamicTypeSize: .large))
    }

    @Test("A 560 pt exactement ou au-dessus, les colonnes restent cote a cote")
    func staysSideBySideAtOrAboveThreshold() {
        let threshold = SlateGeometry.columnStackThreshold
        #expect(!ColumnFractions.shouldStack(availableWidth: threshold, dynamicTypeSize: .large))
        #expect(!ColumnFractions.shouldStack(availableWidth: 720, dynamicTypeSize: .large))
    }

    @Test("A .accessibility1 et au-dela, les colonnes s'empilent quelle que soit la largeur")
    func stacksAtAccessibility1RegardlessOfWidth() {
        #expect(ColumnFractions.shouldStack(availableWidth: 900, dynamicTypeSize: .accessibility1))
        #expect(ColumnFractions.shouldStack(availableWidth: 900, dynamicTypeSize: .accessibility5))
    }
}

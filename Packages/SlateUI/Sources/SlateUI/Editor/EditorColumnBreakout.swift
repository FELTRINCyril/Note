import SwiftUI

/// Largeur reellement disponible dans le panneau editeur, mesuree et publiee par
/// `EditorContentColumn` (voir sa documentation, section "Sortie de colonne d'un bloc
/// individuel"). Valeur par defaut = largeur standard (`editorMaxContentWidth +
/// editorGutter`) : un bloc qui lirait cette valeur HORS d'un `EditorContentColumn`
/// (previews isolees, tests) se comporte comme si la colonne faisait sa largeur
/// standard, jamais comme une largeur nulle ou infinie.
struct EditorAvailableWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat {
        SlateGeometry.editorMaxContentWidth + SlateGeometry.editorGutter
    }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SlateEditorAvailableWidthKey: EnvironmentKey {
    static var defaultValue: CGFloat {
        SlateGeometry.editorMaxContentWidth + SlateGeometry.editorGutter
    }
}

public extension EnvironmentValues {
    /// Largeur du panneau editeur mesuree par `EditorContentColumn` la plus proche
    /// (voir sa documentation). Lue par `View.slateBreakOutOfEditorColumn(targetWidth:)`
    /// pour calculer la largeur de debord d'un bloc, jamais par un bloc ordinaire.
    var slateEditorAvailableWidth: CGFloat {
        get { self[SlateEditorAvailableWidthKey.self] }
        set { self[SlateEditorAvailableWidthKey.self] = newValue }
    }
}

public extension View {
    /// Laisse le CONTENU d'un bloc deborder de la colonne de texte standard (720 pt +
    /// gouttiere de 48 pt), jusqu'a `targetWidth` (`nil` = "pleine largeur", suit la
    /// largeur disponible du panneau editeur plutot qu'une valeur figee -- palier
    /// `.fullWidth` de `SlateImageAlignment`).
    ///
    /// A appliquer sur le CONTENU du bloc (l'image, la rangee de colonnes...), JAMAIS
    /// sur `BlockContainer` lui-meme ni sur le resultat de `EditorContentColumn` : la
    /// gouttiere de chrome (`BlockHandle`) est positionnee AVANT le contenu dans
    /// `BlockContainer` et ne depend pas de sa largeur, elle reste alignee sur la
    /// colonne standard quel que soit `targetWidth` ici -- c'est precisement ce qui
    /// garantit que les poignees de tous les blocs restent sur une meme verticale
    /// (voir la documentation d'`EditorContentColumn`).
    ///
    /// Degrade gracieusement si le panneau est plus etroit que `targetWidth` : la
    /// largeur resultante est toujours cappee a ce que le panneau peut reellement
    /// offrir (jamais un debord force au-dela de la fenetre), au prix d'un rognage par
    /// les bords du `ScrollView` si meme la largeur standard ne tient pas -- non
    /// verifiable visuellement dans cette session (aucune fenetre disponible).
    func slateBreakOutOfEditorColumn(targetWidth: CGFloat?) -> some View {
        modifier(SlateColumnBreakoutModifier(targetWidth: targetWidth))
    }
}

private struct SlateColumnBreakoutModifier: ViewModifier {
    let targetWidth: CGFloat?

    @Environment(\.slateEditorAvailableWidth) private var availableWidth

    func body(content: Content) -> some View {
        let width = EditorColumnBreakout.resolvedWidth(targetWidth: targetWidth, availableWidth: availableWidth)
        content.frame(width: width, alignment: .leading)
    }
}

/// Calcul PUR (aucune dependance SwiftUI au-dela de `CGFloat`) de la largeur de debord
/// resolue par `slateBreakOutOfEditorColumn(targetWidth:)` -- extrait de
/// `SlateColumnBreakoutModifier` pour rester testable independamment d'une hierarchie de
/// vues (meme motif que `ColumnFractions`).
enum EditorColumnBreakout {
    /// Reproduit exactement la formule de repartition des deux `Spacer` d'
    /// `EditorContentColumn` (largeur standard centree, marge minimale `Spacing.xl`)
    /// pour deriver la largeur de CONTENU maximale que le panneau peut accorder sans
    /// empieter sur cette marge minimale de l'autre cote. Le contenu d'un bloc siege
    /// APRES la gouttiere (`editorGutter`, 48 pt) dans `BlockContainer` : elle est donc
    /// soustraite ici, en plus de la marge de colonne standard.
    static func resolvedWidth(targetWidth: CGFloat?, availableWidth: CGFloat) -> CGFloat {
        let standardRowWidth = SlateGeometry.editorMaxContentWidth + SlateGeometry.editorGutter
        let leadingInset = max(Spacing.xl, (availableWidth - standardRowWidth) / 2)
        let maxAllowedContentWidth = max(
            SlateGeometry.editorMaxContentWidth,
            availableWidth - leadingInset - SlateGeometry.editorGutter - Spacing.xl
        )
        guard let targetWidth else { return maxAllowedContentWidth }
        return min(targetWidth, maxAllowedContentWidth)
    }
}

#Preview("EditorColumnBreakout - debord 960pt, clair") {
    ScrollView {
        EditorContentColumn {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Bloc normal, largeur colonne standard.")
                    .slateFont(SlateFont.body)
                Rectangle()
                    .fill(SlateColor.accentDefault.opacity(0.3))
                    .frame(height: 60)
                    .slateBreakOutOfEditorColumn(targetWidth: SlateGeometry.mediaOverflowWidth)
                    .overlay(Text("Debord 960 pt").slateFont(SlateFont.caption))
                Text("Bloc normal suivant, toujours aligne a gauche.")
                    .slateFont(SlateFont.body)
            }
        }
        .padding(.vertical, Spacing.lg)
    }
    .frame(width: 1100, height: 320)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("EditorColumnBreakout - pleine largeur, sombre") {
    ScrollView {
        EditorContentColumn {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Bloc normal, largeur colonne standard.")
                    .slateFont(SlateFont.body)
                    .foregroundStyle(SlateColor.textPrimary)
                Rectangle()
                    .fill(SlateColor.accentDefault.opacity(0.3))
                    .frame(height: 60)
                    .slateBreakOutOfEditorColumn(targetWidth: nil)
                    .overlay(
                        Text("Pleine largeur")
                            .slateFont(SlateFont.caption)
                            .foregroundStyle(SlateColor.textPrimary)
                    )
            }
        }
        .padding(.vertical, Spacing.lg)
    }
    .frame(width: 1100, height: 260)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}

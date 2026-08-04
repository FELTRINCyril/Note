import SwiftUI

/// Colonne de texte centree de l'editeur, largeur max `SlateGeometry.
/// editorMaxContentWidth` (720 pt), avec la gouttiere de chrome (`editorGutter`, 48 pt)
/// incluse dans la largeur totale reservee quand `includesGutter` est vrai. Utilisee
/// pour l'en-tete de note ET pour chaque bloc : c'est ce qui garantit que titre,
/// sous-titre et corps partagent exactement la meme marge de gauche (spec E4,
/// "Principe").
///
/// Voir la documentation de `EditorGeometry.swift` (section "Choix de mise en page
/// retenu pour la gouttiere") pour l'arbitrage : la gouttiere est INCLUSE dans le flux
/// (elargit la boite centree a `720 + 48`) plutot que flottante en overlay, pour rester
/// robuste dans un panneau d'editeur redimensionnable. Consequence acceptee : la
/// colonne de texte, bien que strictement 720 pt de large, est optiquement decalee
/// d'environ `editorGutter / 2` (24 pt) vers la droite par rapport au centre exact de
/// la fenetre.
public struct EditorContentColumn<Content: View>: View {
    private let includesGutter: Bool
    private let content: Content

    public init(includesGutter: Bool = true, @ViewBuilder content: () -> Content) {
        self.includesGutter = includesGutter
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: Spacing.xl)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: columnWidth, alignment: .leading)
            Spacer(minLength: Spacing.xl)
        }
    }

    private var columnWidth: CGFloat {
        SlateGeometry.editorMaxContentWidth + (includesGutter ? SlateGeometry.editorGutter : 0)
    }
}

#Preview("EditorContentColumn - clair") {
    EditorContentColumn {
        Text("Colonne centree, 720 pt + gouttiere de 48 pt.")
            .slateFont(SlateFont.body)
            .foregroundStyle(SlateColor.textPrimary)
    }
    .frame(width: 900, height: 200)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("EditorContentColumn - sombre") {
    EditorContentColumn {
        Text("Colonne centree, 720 pt + gouttiere de 48 pt.")
            .slateFont(SlateFont.body)
            .foregroundStyle(SlateColor.textPrimary)
    }
    .frame(width: 900, height: 200)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}

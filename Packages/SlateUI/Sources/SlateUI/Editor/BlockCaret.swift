import SwiftUI

/// Curseur de saisie de l'editeur de blocs (spec E4, "Caret, selection, depot") : 2 pt
/// de large, couleur d'accent (`insertionPoint` macOS), clignotement d'un cycle complet
/// de 1,06 s.
///
/// "Le caret vit toujours dans un bloc : passer de l'un a l'autre au clavier ne dessine
/// aucune ligne intermediaire" (spec E4) -- ce composant n'a donc pas de notion de
/// position entre blocs : c'est a l'appelant de le placer dans le contenu du bloc
/// focalise, avec la hauteur de ligne REELLE de ce contenu (Dynamic Type : "la hauteur
/// de la poignee suit l'interligne reel").
public struct BlockCaret: View {
    /// Hauteur de ligne du contenu dans lequel ce caret est place. Doit suivre le
    /// Dynamic Type de l'appelant (ex : `15 * SlateGeometry.editorParagraphLineHeight`
    /// mis a l'echelle), pas une constante figee.
    private let lineHeight: CGFloat
    /// Figeable pour un rendu statique (ex : previews, tests de capture). `true` par
    /// defaut : le clignotement reste desactive si "Reduce Motion" est actif, voir
    /// `body`.
    private let isBlinking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = true

    public init(lineHeight: CGFloat, isBlinking: Bool = true) {
        self.lineHeight = lineHeight
        self.isBlinking = isBlinking
    }

    public var body: some View {
        Rectangle()
            .fill(SlateColor.caretColor)
            .frame(width: SlateGeometry.editorCaretWidth, height: lineHeight)
            .opacity(isVisible ? 1 : 0)
            .onAppear(perform: startBlinkingIfNeeded)
            // Decoratif : le vrai curseur de saisie est porte par le champ de texte
            // sous-jacent (TextKit/TextField), pas par ce rectangle.
            .accessibilityHidden(true)
    }

    private func startBlinkingIfNeeded() {
        guard isBlinking, !reduceMotion else {
            isVisible = true
            return
        }
        withAnimation(.linear(duration: SlateMotion.caretBlinkHalfCycle).repeatForever(autoreverses: true)) {
            isVisible = false
        }
    }
}

#Preview("BlockCaret - clair") {
    BlockCaret(lineHeight: 22.5)
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("BlockCaret - sombre") {
    BlockCaret(lineHeight: 22.5)
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

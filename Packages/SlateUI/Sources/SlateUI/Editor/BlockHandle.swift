import SwiftUI

/// Chrome de bloc revele au survol : bouton "+" (inserer un bloc en dessous) puis
/// poignee de menu/glissement, alignes sur `SlateGeometry.editorGutter` (spec E4,
/// "Etats d'un bloc"). Composant reutilisable par tous les types de blocs futurs
/// (paragraphe, titre, liste, citation, code...) : neutre quant au CONTENU du bloc,
/// voir `BlockContainer`.
///
/// "Le chrome apparait en 120 ms, le texte ne bouge pas" (spec E4) : ce composant vit
/// TOUJOURS a une largeur fixe (`editorGutter`) et ne fait que varier son opacite --
/// jamais sa taille -- pour ne jamais perturber la mise en page du texte voisin.
public struct BlockHandle: View {
    /// Chrome visible ? Pilote par l'etat du bloc (`SlateBlockState.showsChrome`) ou le
    /// survol local, decide par l'appelant (`BlockContainer`).
    private let isVisible: Bool
    /// Identifiant opaque du bloc, pour le glisser-deposer (`.draggable`). `SlateUI` ne
    /// connait pas le modele de bloc reel : une simple `String` suffit ici.
    private let dragPayload: String
    private let onInsert: () -> Void
    private let onMenu: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        isVisible: Bool,
        dragPayload: String = "",
        onInsert: @escaping () -> Void = {},
        onMenu: @escaping () -> Void = {}
    ) {
        self.isVisible = isVisible
        self.dragPayload = dragPayload
        self.onInsert = onInsert
        self.onMenu = onMenu
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            BlockChromeButton(
                systemName: "plus",
                helpText: SlateUIStrings.blockHandleInsertHelp,
                action: onInsert
            )
            .accessibilityLabel(SlateUIStrings.blockHandleInsertLabel)

            BlockChromeButton(
                systemName: "line.3.horizontal",
                helpText: SlateUIStrings.blockHandleMenuHelp,
                action: onMenu
            )
            .accessibilityLabel(SlateUIStrings.blockHandleMenuLabel)
            .draggable(dragPayload)
        }
        .frame(width: SlateGeometry.editorGutter, alignment: .trailing)
        .opacity(isVisible ? 1 : 0)
        .animation(chromeAnimation, value: isVisible)
        // Le chrome reste hors du flux du texte : masque, il ne doit pas non plus etre
        // atteignable au clavier/VoiceOver ni intercepter les clics.
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
    }

    private var chromeAnimation: Animation? {
        SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion)
    }
}

/// Bouton glyphe unique du chrome de bloc, dimensionne a `SlateGeometry.blockHandleSize`
/// (18 pt visuels) avec une cible cliquable elargie a `blockHandleHitAreaSize` (24 pt),
/// sans changer la metrique visuelle (spec E4 : "18 pt visuels, cible 24 pt").
private struct BlockChromeButton: View {
    let systemName: String
    let helpText: String
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .slateIconFont(SlateGeometry.blockHandleGlyphSize, weight: .medium)
                .foregroundStyle(isHovering ? SlateColor.blockHandleHover : SlateColor.blockHandleIdle)
                .frame(width: SlateGeometry.blockHandleSize, height: SlateGeometry.blockHandleSize)
                .background(
                    RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                        .fill(isHovering ? SlateColor.blockHandleHoverBackground : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            let animation = SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion)
            withAnimation(animation) {
                isHovering = hovering
            }
        }
        .help(helpText)
        // Cible de clic elargie a `blockHandleHitAreaSize` (24 pt) sans agrandir le
        // glyphe visuel (18 pt) : le premier `padding` etend la zone de detection du
        // tap, le second compense pour que la taille RAPPORTEE au parent (donc la mise
        // en page du chrome) reste inchangee.
        .padding(chromeHitAreaMargin)
        .padding(-chromeHitAreaMargin)
    }

    private var chromeHitAreaMargin: CGFloat {
        (SlateGeometry.blockHandleHitAreaSize - SlateGeometry.blockHandleSize) / 2
    }
}

#Preview("BlockHandle - visible, clair") {
    BlockHandle(isVisible: true)
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("BlockHandle - visible, sombre") {
    BlockHandle(isVisible: true)
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

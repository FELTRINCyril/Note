import SlateUI
import SwiftUI

/// Bouton de la barre de formatage flottante (artboard P1 A, "Etats des boutons") :
/// repos (icone `text.primary`, fond transparent), survol (`state.hover`, 120 ms),
/// ACTIF (`accent.default` plein + `text.onAccent`, ET `accessibilityValue` = "active" --
/// l'etat ne doit pas etre porte par la seule couleur), focus clavier (anneau
/// `focusRing` 3 pt, visuellement DISTINCT de l'actif : un CONTOUR, jamais un aplat),
/// desactive (opacite 0,4).
///
/// ## Non verifie dans une fenetre reelle
/// Aucune fenetre n'est disponible dans cet environnement pour confirmer que cliquer ce
/// bouton (un vrai contro le AppKit sous le capot d'un `Button` SwiftUI) laisse
/// effectivement la selection de texte du `NSTextView` intacte le temps que l'action
/// s'execute (voir la documentation de tete de `FormatBarOverlay`, meme risque que celui
/// deja signale pour `BlockMenuView` en Phase 5 -- ce fichier suit exactement le meme
/// precedent de `.popover` deja en production, pas un mecanisme nouveau).
struct FormatBarButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var isActive: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .slateIconFont(SlateGeometry.blockHandleGlyphSize, relativeTo: .body)
                .foregroundStyle(isActive ? SlateColor.textOnAccent : SlateColor.textPrimary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .background(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            // Focus clavier : un CONTOUR, jamais un aplat -- visuellement distinct de
            // l'etat ACTIF (aplat plein `accent.default`, voir `backgroundColor`).
            RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall, style: .continuous)
                .strokeBorder(SlateColor.focusRing, lineWidth: isFocused ? SlateGeometry.focusRingWidth : 0)
        )
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.12), value: isHovering)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isActive ? EditorStrings.formatBarActiveValue : "")
    }

    private var backgroundColor: Color {
        if isActive { SlateColor.accentDefault } else if isHovering { SlateColor.stateHover } else { .clear }
    }
}

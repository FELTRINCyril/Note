import AppKit
import SwiftUI

/// Fond materiau natif de la barre laterale (`NSVisualEffectView` materiau `.sidebar`).
///
/// SwiftUI n'expose pas de cas `.sidebar` dans son enum `Material` (introduit en
/// macOS 12) : seul AppKit le propose, d'ou ce pont `NSViewRepresentable`. `SlateUI` est
/// autorise a importer AppKit (voir CLAUDE.md §4, contrairement a `SlateModel`).
private struct SidebarMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Applique le fond de barre laterale : materiau natif `.sidebar`, ou repli sur l'aplat
/// `SlateColor.bgSidebarOpaque` quand "Reduce Transparency" est actif (spec E2
/// Accessibilite : "le materiau .sidebar retombe sur l'aplat #F2F2F5 / #232326").
///
/// Phase 13 : le reglage Slate "Reduire la transparence de la barre laterale" (design P4)
/// S'AJOUTE au reglage systeme (`accessibilityReduceTransparency`) -- l'un OU l'autre
/// suffit a opacifier, ni l'un ni l'autre ne l'emporte silencieusement sur son
/// complement (voir la note de `ThemeManager.reducesSidebarTransparency`).
private struct SlateSidebarBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency

    func body(content: Content) -> some View {
        content.background {
            if systemReducesTransparency || slateReducesSidebarTransparencyOverride() {
                SlateColor.bgSidebarOpaque
            } else {
                SidebarMaterialBackground()
            }
        }
    }
}

public extension View {
    /// Fond de la colonne sidebar : materiau translucide natif, avec repli automatique
    /// sur un aplat opaque si l'utilisateur a active "Reduce Transparency".
    func slateSidebarBackground() -> some View {
        modifier(SlateSidebarBackgroundModifier())
    }
}

#Preview("slateSidebarBackground - clair") {
    VStack(alignment: .leading, spacing: 4) {
        SidebarSectionHeader("Favoris")
        SidebarRow(title: "Feuille de route Q3", isSelected: true) {
            // La ligne est selectionnee : l'icone doit passer sur la couleur de
            // premier plan de l'aplat d'accent, sinon elle tombe sous le seuil AA
            // (cf. OnAccentFillContrastTests). Taille via token, jamais en dur.
            Image(systemName: "star.fill")
                .slateIconFont(SlateGeometry.sidebarBadgeIconSize, relativeTo: .subheadline)
                .foregroundStyle(SlateColor.foregroundOnAccentFill)
        }
    }
    .frame(width: 240, height: 200, alignment: .top)
    .slateSidebarBackground()
}

#Preview("slateSidebarBackground - sombre") {
    VStack(alignment: .leading, spacing: 4) {
        SidebarSectionHeader("Favoris")
        SidebarRow(title: "Feuille de route Q3", isSelected: true) {
            // La ligne est selectionnee : l'icone doit passer sur la couleur de
            // premier plan de l'aplat d'accent, sinon elle tombe sous le seuil AA
            // (cf. OnAccentFillContrastTests). Taille via token, jamais en dur.
            Image(systemName: "star.fill")
                .slateIconFont(SlateGeometry.sidebarBadgeIconSize, relativeTo: .subheadline)
                .foregroundStyle(SlateColor.foregroundOnAccentFill)
        }
    }
    .frame(width: 240, height: 200, alignment: .top)
    .slateSidebarBackground()
    .preferredColorScheme(.dark)
}

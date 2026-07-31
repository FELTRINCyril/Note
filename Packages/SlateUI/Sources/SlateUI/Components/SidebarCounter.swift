import SwiftUI

/// Compteur discret d'une ligne de sidebar (ex: nombre de notes d'un dossier).
///
/// Chiffres tabulaires (spec E2 : "12 pt, chiffres tabulaires") pour que la largeur de
/// la ligne ne "danse" pas quand le nombre change. Aucune notion de dossier : c'est un
/// simple rendu d'entier, l'appelant fournit la valeur et, s'il le souhaite, un libelle
/// d'accessibilite adapte au contexte (ex: "12 notes").
public struct SidebarCounter: View {
    private let count: Int
    private let accessibilityLabelOverride: String?

    /// Vrai quand la ligne parente est actuellement posee sur l'aplat plein de
    /// selection (`SidebarRow`, ligne selectionnee + fenetre active). Dans ce cas
    /// `text.tertiary` (26% d'opacite) chute a ~1,59:1 une fois compose sur l'aplat --
    /// tres loin de l'AA -- il faut alors basculer sur `SlateColor.foregroundOnAccentFill`.
    /// Voir `OnAccentFill.swift`.
    @Environment(\.slateIsOnAccentFill) private var isOnAccentFill

    public init(count: Int, accessibilityLabel: String? = nil) {
        self.count = count
        self.accessibilityLabelOverride = accessibilityLabel
    }

    public var body: some View {
        Text(count, format: .number)
            .slateFont(SlateFont.sidebarCounter)
            .foregroundStyle(SlateColor.foreground(SlateColor.textTertiary, onAccentFill: isOnAccentFill))
            .modifier(OptionalAccessibilityLabelModifier(label: accessibilityLabelOverride))
    }
}

/// Applique `.accessibilityLabel` uniquement si une valeur est fournie, pour ne pas
/// imposer un libelle generique quand l'appelant a une phrase plus precise (ex: compose
/// par `SlateFeatures` dans une ligne complete de dossier).
private struct OptionalAccessibilityLabelModifier: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

#Preview("SidebarCounter") {
    HStack(spacing: 16) {
        SidebarCounter(count: 2)
        SidebarCounter(count: 12)
        SidebarCounter(count: 1_024)
    }
    .padding()
    .background(SlateColor.bgSidebarOpaque)
}

#Preview("SidebarCounter - sombre") {
    HStack(spacing: 16) {
        SidebarCounter(count: 2)
        SidebarCounter(count: 12)
        SidebarCounter(count: 1_024)
    }
    .padding()
    .background(SlateColor.bgSidebarOpaque)
    .preferredColorScheme(.dark)
}

#Preview("SidebarCounter - sur aplat de selection (clair)") {
    HStack(spacing: 16) {
        SidebarCounter(count: 2)
        SidebarCounter(count: 12)
        SidebarCounter(count: 1_024)
    }
    .padding()
    .background(SlateColor.accentSelectionFill)
    .environment(\.slateIsOnAccentFill, true)
}

#Preview("SidebarCounter - sur aplat de selection (sombre)") {
    HStack(spacing: 16) {
        SidebarCounter(count: 2)
        SidebarCounter(count: 12)
        SidebarCounter(count: 1_024)
    }
    .padding()
    .background(SlateColor.accentSelectionFill)
    .environment(\.slateIsOnAccentFill, true)
    .preferredColorScheme(.dark)
}

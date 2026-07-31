import SwiftUI

/// Chevron de pliage/depliage d'une ligne de sidebar, generique (aucune notion de
/// dossier ni de SwiftData : `SlateFeatures` decide de ce qu'il plie).
///
/// Respecte la spec E2 : glyphe 10 pt semibold en `text.tertiary`, rotation 0 -> 90
/// degres, zone cliquable de 14 pt distincte du reste de la ligne (pour ne pas gener le
/// clic de selection). Respecte "Reduce Motion" : la rotation n'est pas animee si actif.
public struct DisclosureChevron: View {
    private let isExpanded: Bool
    private let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Vrai quand le chevron est pose sur l'aplat plein de selection : meme defaut que
    /// `SidebarCounter` (`text.tertiary` illisible sur `accentSelectionFill`), meme
    /// correctif. Voir `OnAccentFill.swift`.
    @Environment(\.slateIsOnAccentFill) private var isOnAccentFill

    public init(isExpanded: Bool, action: @escaping () -> Void) {
        self.isExpanded = isExpanded
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .slateIconFont(SlateGeometry.sidebarChevronSize, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(SlateColor.foreground(SlateColor.sidebarChevron, onAccentFill: isOnAccentFill))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: SlateGeometry.sidebarChevronHitArea, height: SlateGeometry.sidebarChevronHitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(
            SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion),
            value: isExpanded
        )
        .accessibilityLabel(isExpanded ? "Replier" : "Deplier")
    }
}

#Preview("DisclosureChevron - replie / deplie") {
    HStack(spacing: 24) {
        DisclosureChevron(isExpanded: false) {}
        DisclosureChevron(isExpanded: true) {}
    }
    .padding()
    .background(SlateColor.bgSidebarOpaque)
}

#Preview("DisclosureChevron - sombre") {
    HStack(spacing: 24) {
        DisclosureChevron(isExpanded: false) {}
        DisclosureChevron(isExpanded: true) {}
    }
    .padding()
    .background(SlateColor.bgSidebarOpaque)
    .preferredColorScheme(.dark)
}

#Preview("DisclosureChevron - sur aplat de selection") {
    HStack(spacing: 24) {
        DisclosureChevron(isExpanded: false) {}
        DisclosureChevron(isExpanded: true) {}
    }
    .padding()
    .background(SlateColor.accentSelectionFill)
    .environment(\.slateIsOnAccentFill, true)
}

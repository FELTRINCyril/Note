import SwiftUI
import SlateUI

/// Une pastille d'accent (design P4 artboard A : "8 pastilles ... chaque teinte est
/// nommee au survol et lue par VoiceOver (\"Bleu, selectionne\"). La selection est
/// marquee par une coche EN PLUS de l'anneau" -- jamais la couleur seule, regle
/// "Daltonisme" du design system).
///
/// `SlateAccentColor` (Phase 13, `SlateUI`) n'expose que ses composantes RGB brutes
/// (`lightRGB`/`darkRGB`), pas de `Color` adaptative toute faite (`slateAdaptiveColor`
/// est interne a `SlateUI`) : cette vue lit `\.colorScheme` elle-meme pour choisir la
/// bonne paire, seul endroit de `SlateFeatures` a le faire pour une couleur d'accent.
struct AccentSwatchButton: View {
    let color: SlateAccentColor
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private static let diameter: CGFloat = 22

    private var swatchColor: Color {
        let rgb = colorScheme == .dark ? color.darkRGB : color.lightRGB
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: rgb.alpha)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(swatchColor)
                    .frame(width: Self.diameter, height: Self.diameter)
                Circle()
                    .strokeBorder(SlateColor.focusRing, lineWidth: isSelected ? SlateGeometry.strokeHairline * 2 : 0)
                    .frame(width: Self.diameter + Spacing.xs, height: Self.diameter + Spacing.xs)
                if isSelected {
                    let onAccentRGB = color.onAccentRGB(dark: colorScheme == .dark)
                    Image(systemName: "checkmark")
                        .slateIconFont(SlateGeometry.sidebarBadgeIconSize, weight: .bold, relativeTo: .caption)
                        .foregroundStyle(
                            Color(red: onAccentRGB.red, green: onAccentRGB.green, blue: onAccentRGB.blue)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(
            isSelected
                ? String(format: accentSelectedFormat, name)
                : name
        )
    }

    private var accentSelectedFormat: String {
        String(localized: "settings.appearance.accent.selectedFormat", bundle: .module)
    }
}

#Preview("AccentSwatchButton") {
    HStack(spacing: Spacing.sm) {
        AccentSwatchButton(color: .blue, name: "Bleu", isSelected: true) {}
        AccentSwatchButton(color: .green, name: "Vert", isSelected: false) {}
    }
    .padding(Spacing.lg)
}

import SwiftUI

/// Bloc callout (design/tokens.md §16 bis, artboard F). Composant de PRESENTATION pur :
/// ne connait ni `Block` ni `Note` (CLAUDE.md §4), recoit son contenu en `@ViewBuilder`.
/// Le chrome de selection/focus est porte par `BlockContainer` (`SlateBlockChrome`), pas
/// par cette vue : un callout est un CONTENU de bloc, pas un `BlockContainer` a lui seul.
public struct CalloutBlockView<Content: View>: View {
    private let variant: SlateCalloutVariant
    private let content: Content

    public init(_ variant: SlateCalloutVariant, @ViewBuilder content: () -> Content) {
        self.variant = variant
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm + Spacing.xs) {
            Image(systemName: variant.symbol)
                .slateIconFont(SlateGeometry.calloutIconSize, weight: .regular, relativeTo: .body)
                .foregroundStyle(variant.labelColor)
                // Le libelle textuel porte deja le sens de la variante : l'icone ne doit
                // pas etre annoncee une seconde fois a VoiceOver.
                .accessibilityHidden(variant.label != nil)
            VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                if let label = variant.label {
                    Text(label)
                        .slateFont(SlateFont.bodyEmphasis)
                        .foregroundStyle(variant.labelColor)
                }
                content
                    .slateFont(SlateFont.body)
                    .foregroundStyle(SlateColor.textPrimary) // le corps ne se teinte jamais
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            variant.background,
            in: RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium, style: .continuous)
                .strokeBorder(variant.border, lineWidth: SlateGeometry.strokeHairline)
        )
        .padding(.vertical, SlateGeometry.decoratedBlockSpacing)
    }
}

#Preview("CalloutBlockView - 4 variantes, clair") {
    CalloutGalleryPreview()
        .environment(\.colorScheme, .light)
}

#Preview("CalloutBlockView - 4 variantes, sombre") {
    CalloutGalleryPreview()
        .environment(\.colorScheme, .dark)
}

private struct CalloutGalleryPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(SlateCalloutVariant.allCases) { variant in
                CalloutBlockView(variant) {
                    Text("Texte du callout \(variant.rawValue).")
                }
            }
        }
        .padding(Spacing.lg)
        .frame(width: 560)
        .background(SlateColor.bgEditor)
    }
}

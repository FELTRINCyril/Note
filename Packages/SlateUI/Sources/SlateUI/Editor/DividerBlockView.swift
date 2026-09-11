import SwiftUI

/// Bloc separateur (design/tokens.md §16, artboard G) : trait de `strokeHairline`
/// (1 pt) en `divider.color`, dans une cible de selection agrandie a `dividerHitHeight`
/// (24 pt) pour rester facilement selectionnable a la souris.
public struct DividerBlockView: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(SlateColor.dividerColor)
            .frame(height: SlateGeometry.strokeHairline)
            .frame(height: SlateGeometry.dividerHitHeight)
            .contentShape(Rectangle())
            .accessibilityLabel("Separateur")
    }
}

#Preview("DividerBlockView - clair") {
    VStack {
        Text("Au-dessus")
        DividerBlockView()
        Text("En dessous")
    }
    .padding(Spacing.lg)
    .frame(width: 480)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("DividerBlockView - sombre") {
    VStack {
        Text("Au-dessus")
        DividerBlockView()
        Text("En dessous")
    }
    .padding(Spacing.lg)
    .frame(width: 480)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}

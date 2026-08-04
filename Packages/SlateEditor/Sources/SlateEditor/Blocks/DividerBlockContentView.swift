import SlateUI
import SwiftUI

/// Separateur horizontal (`BlockType.divider`) : sans texte ni attributs, un simple
/// filet `SlateColor.dividerColor`.
struct DividerBlockContentView: View {
    var body: some View {
        Rectangle()
            .fill(SlateColor.dividerColor)
            .frame(height: SlateGeometry.strokeHairline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .accessibilityLabel("Separateur")
    }
}

#Preview("DividerBlockContentView - clair") {
    DividerBlockContentView()
        .padding()
        .frame(width: 400)
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("DividerBlockContentView - sombre") {
    DividerBlockContentView()
        .padding()
        .frame(width: 400)
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

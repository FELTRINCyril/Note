import SlateUI
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// Image de couverture optionnelle d'une note (spec E4 : "couverture 200 pt, pleine
/// largeur"). Lecture seule en 5.1 : les actions "Repositionner / Changer / Supprimer"
/// visibles dans la maquette au survol sont des capacites d'EDITION de la couverture,
/// hors perimetre demande pour cette sous-etape (seul le titre est editable en 5.1).
struct NoteCoverView: View {
    let imageData: Data
    let accessibilityLabel: String

    var body: some View {
        Group {
            #if canImport(AppKit)
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                SlateColor.surfaceSecondary
            }
            #else
            SlateColor.surfaceSecondary
            #endif
        }
        .frame(height: SlateGeometry.editorCoverHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("NoteCoverView - clair, image invalide") {
    NoteCoverView(imageData: Data(), accessibilityLabel: "Image de couverture")
        .frame(width: 900)
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("NoteCoverView - sombre, image invalide") {
    NoteCoverView(imageData: Data(), accessibilityLabel: "Image de couverture")
        .frame(width: 900)
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

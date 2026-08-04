import SlateUI
import SwiftUI

/// Icone/emoji optionnel d'une note (spec E4 : "icone 64 pt chevauchant de 32 pt").
/// `iconName` est traite comme un nom de symbole systeme, coherent avec le reste du
/// modele (`Folder.iconName`, `Space.iconName`, `Workspace.iconName` sont tous des noms
/// SF Symbols, jamais des emoji -- voir `SlateModel`).
struct NoteIconView: View {
    let iconName: String
    let accessibilityLabel: String

    var body: some View {
        Image(systemName: iconName)
            .slateIconFont(SlateGeometry.editorIconSize * 0.5, relativeTo: .largeTitle)
            .foregroundStyle(SlateColor.textPrimary)
            .frame(width: SlateGeometry.editorIconSize, height: SlateGeometry.editorIconSize)
            .background(
                Circle().fill(SlateColor.surfaceSecondary)
            )
            .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("NoteIconView - clair") {
    NoteIconView(iconName: "map", accessibilityLabel: "Icone de la note")
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("NoteIconView - sombre") {
    NoteIconView(iconName: "map", accessibilityLabel: "Icone de la note")
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

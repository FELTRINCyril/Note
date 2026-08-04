import SlateUI
import SwiftUI

/// Zone cliquable en bas de document (spec E4 : "240 pt de zone cliquable -- un clic y
/// cree un bloc vide focalise").
///
/// En 5.1, cette action n'existait pas encore : la vue reservait l'ESPACE demande par
/// la spec sans installer aucun geste (regle d'honnetete d'interface du projet -- pas
/// de geste factice qui ne ferait rien silencieusement). Depuis la 5.3,
/// `EditorController.appendTrailingParagraph()` existe : le geste reel est installe ICI.
struct NoteDocumentBottomSpacerView: View {
    let onTap: () -> Void

    var body: some View {
        Color.clear
            .frame(height: SlateGeometry.editorContentBottomPadding)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(EditorStrings.appendBlockAccessibilityLabel)
            .accessibilityAddTraits(.isButton)
    }
}

#Preview("NoteDocumentBottomSpacerView") {
    VStack(spacing: 0) {
        Rectangle().fill(SlateColor.textTertiary).frame(height: 2)
        NoteDocumentBottomSpacerView(onTap: {})
    }
    .background(SlateColor.bgEditor)
}

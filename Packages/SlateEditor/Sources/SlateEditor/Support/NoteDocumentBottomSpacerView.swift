import SlateUI
import SwiftUI

/// Zone reservee en bas de document (spec E4 : "240 pt de zone cliquable -- un clic y
/// cree un bloc vide focalise").
///
/// En 5.1, cette action (creer un bloc vide et lui donner le focus) n'existe pas
/// encore : c'est la 5.2/5.3 qui l'implementent. Cette vue reserve donc bien l'ESPACE
/// demande par la spec, mais N'INSTALLE AUCUN GESTE DE CLIC -- ni geste reel, ni geste
/// factice qui ne ferait rien silencieusement (regle d'honnetete d'interface du
/// projet). Pas de `Button`/`onTapGesture`, pas de curseur pointeur : visuellement
/// c'est un simple espace vide, comme le bas de n'importe quel document avant son
/// dernier bloc.
struct NoteDocumentBottomSpacerView: View {
    var body: some View {
        Color.clear
            .frame(height: SlateGeometry.editorContentBottomPadding)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview("NoteDocumentBottomSpacerView") {
    VStack(spacing: 0) {
        Rectangle().fill(SlateColor.textTertiary).frame(height: 2)
        NoteDocumentBottomSpacerView()
    }
    .background(SlateColor.bgEditor)
}

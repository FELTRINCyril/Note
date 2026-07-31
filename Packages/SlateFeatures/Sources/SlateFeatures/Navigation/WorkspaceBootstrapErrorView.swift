import Foundation
import SwiftUI
import SlateUI

/// Affichee si `WorkspaceBootstrap.ensureDefaultWorkspace` echoue (disque plein,
/// contexte non sauvegardable...). Rare, mais ne doit pas etre masquee silencieusement
/// (voir `ContainerErrorView` dans `App/` pour le meme principe applique a l'echec de
/// creation du `ModelContainer`).
struct WorkspaceBootstrapErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label(
                String(localized: "workspaceBootstrap.error.title", bundle: .module),
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(error.localizedDescription)
        }
    }
}

#Preview {
    WorkspaceBootstrapErrorView(error: CocoaError(.fileWriteUnknown))
}

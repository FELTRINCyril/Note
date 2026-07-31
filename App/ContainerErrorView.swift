import SwiftUI

/// Vue affichee si la creation du `ModelContainer` SwiftData a echoue au lancement.
///
/// Phase 1 : la creation du container (`SlateContainer.make()`) peut echouer (disque
/// plein, schema incompatible, etc.). Plutot que de crasher avec `try!`, l'app affiche
/// ce message et l'erreur technique, pour rester diagnosticable sans Xcode attache.
struct ContainerErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label(
                String(localized: "containerError.title", defaultValue: "Impossible de démarrer Slate"),
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(error.localizedDescription)
        }
    }
}

#Preview {
    ContainerErrorView(error: CocoaError(.fileWriteUnknown))
}

import SwiftUI
import SlateModel
import SlateUI

/// Indicateur de synchronisation de la barre d'outils (spec E1, toolbar centrale).
///
/// ## Honnetete de l'affichage
///
/// `SlateServices` n'expose encore aucun etat de synchronisation reel en Phase 3 (le
/// moteur de sync CloudKit arrive dans une phase ulterieure) : afficher "A jour" comme
/// le fait la maquette serait donc un mensonge d'interface (rien ne garantit que quoi
/// que ce soit est synchronise). Ce composant se limite a annoncer un FAIT verifiable
/// au moment de la compilation : `SlateContainer.isCloudKitEnabled` (vrai en Release
/// uniquement, faux en Debug - voir `docs/DEV_ENV.md`). Aucune pretention de
/// fraicheur ("a jour", "synchronise a l'instant") n'est faite tant que
/// `SlateServices` ne remonte pas un etat reel.
struct SyncStatusView: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: SlateContainer.isCloudKitEnabled ? "icloud" : "icloud.slash")
                .slateIconFont(SlateGeometry.toolbarIconSize, relativeTo: .caption)
                .foregroundStyle(SlateColor.textTertiary)
            Text(statusText)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
    }

    private var statusText: String {
        SlateContainer.isCloudKitEnabled
            ? String(localized: "toolbar.sync.enabled", bundle: .module)
            : String(localized: "toolbar.sync.disabledDebug", bundle: .module)
    }
}

#Preview("SyncStatusView") {
    SyncStatusView()
        .padding()
}

#Preview("SyncStatusView - sombre") {
    SyncStatusView()
        .padding()
        .preferredColorScheme(.dark)
}

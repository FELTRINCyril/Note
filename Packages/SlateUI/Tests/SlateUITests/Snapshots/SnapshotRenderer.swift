import AppKit
import SwiftUI

/// Utilitaire de verification visuelle (mission "vérification visuelle", pas une phase
/// numerotee du plan) : rend une vue SwiftUI pure en PNG SANS fenetre, via
/// `ImageRenderer`, et l'ecrit dans `/tmp/slate_snapshots/`. C'est la seule facon
/// mesuree de "voir" un composant `SlateUI` dans cet environnement -- aucune fenetre
/// n'est disponible et la capture d'ecran systeme est bloquee.
///
/// ## Limite mesuree, a respecter par les appelants
/// `ImageRenderer` ne rend QUE du SwiftUI pur. Un `ScrollView`, une
/// `NavigationSplitView`, un materiau translucide (`.thinMaterial`...) ou un pont
/// `NSViewRepresentable` produit une image blanche ou un pictogramme "interdit" plutot
/// qu'une erreur explicite -- ne pas s'etonner d'un PNG vide si la vue passee en
/// contient un. Cet utilitaire cible volontairement les composants de PRESENTATION de
/// `SlateUI` (CLAUDE.md §4), qui n'utilisent aucun de ces trois mecanismes.
///
/// ## Pourquoi `@MainActor`
/// `ImageRenderer`/`NSBitmapImageRep` touchent a AppKit : isoler la fonction sur
/// l'acteur principal serialise les rendus entre eux (un seul a la fois sur le thread
/// UI), plutot que de risquer un rendu concurrent depuis le pool de threads
/// d'arriere-plan sur lequel Swift Testing execute les `@Test` non isoles par defaut
/// (meme risque documente dans `ThemeManager.swift` a propos de `MainActor.
/// assumeIsolated`, ici evite en isolant directement la fonction plutot qu'en y
/// entrant depuis un contexte non isole).
@MainActor
enum SnapshotRenderer {
    enum SnapshotError: Error, CustomStringConvertible {
        case renderingFailed(String)
        case encodingFailed(String)

        var description: String {
            switch self {
            case let .renderingFailed(name): "ImageRenderer n'a produit aucune image pour \"\(name)\"."
            case let .encodingFailed(name): "Echec de l'encodage PNG pour \"\(name)\"."
            }
        }
    }

    /// Dossier de sortie. Volontairement HORS du depot (`/tmp`, pas `design/` ni
    /// `Tests/`) : ce sont des artefacts de verification, pas des sources versionnees.
    static let outputDirectory = URL(fileURLWithPath: "/tmp/slate_snapshots", isDirectory: true)

    /// Rend `view` et ecrit `<name>.png` dans `outputDirectory`, en creant le dossier au
    /// besoin. `scale` a 2 par defaut (Retina) pour un rendu net a l'inspection.
    static func render(
        _ view: some View,
        named name: String,
        scale: CGFloat = 2
    ) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale

        guard let image = renderer.nsImage else {
            throw SnapshotError.renderingFailed(name)
        }
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw SnapshotError.encodingFailed(name)
        }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let url = outputDirectory.appendingPathComponent("\(name).png")
        try png.write(to: url)
    }
}

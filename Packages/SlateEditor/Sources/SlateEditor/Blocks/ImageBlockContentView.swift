import AppKit
import SlateModel
import SlateServices
import SlateUI
import SwiftUI
import UniformTypeIdentifiers

/// Bloc image (`BlockType.image`, Phase 9, artboard A). Ne porte AUCUN `RichText` --
/// pas de `NSTextView`, contrairement a tous les blocs texte de ce module -- donc aucun
/// caret : la "focalisation" de ce bloc est toujours la SELECTION generique
/// (`EditorController.selectedBlockID`, voir `BlockTreeView`), jamais
/// `focusedBlockID`.
///
/// ## Les 4 etats de l'artboard
/// - **vide** : `block.attachment == nil` et aucun import en cours -> `MediaDropzoneView`.
/// - **survol de depot** : idem, `isDropTargeted` vrai pendant un glisser-depose au
///   dessus de CE bloc precis.
/// - **chargement** : import en cours (`importPhase`) -> `MediaUploadProgressView`.
/// - **affichee/selectionnee** : `block.attachment != nil` -> `ImageFrameView`, controles
///   de palier/legende/redimensionnement visibles uniquement si `isSelected`.
///
/// ## Ecart assume : pas de vraie progression incrementale
/// `AttachmentService.importImage` est une operation SYNCHRONE (decodage + eventuelle
/// recompression `ImageIO`) : ce fichier ne peut pas en tirer un pourcentage reel. La
/// barre de `MediaUploadProgressView` reste affichee le temps de l'operation (via
/// `Task.detached`, pour ne jamais bloquer le fil principal sur une image volumineuse)
/// mais ne progresse pas de facon continue -- ecart documente, pas un oubli.
///
/// ## Paliers hors colonne (Phase 10)
/// `.overflow` (960 pt) et `.fullWidth` (largeur du panneau) utilisent desormais
/// `View.slateBreakOutOfEditorColumn(targetWidth:)` (`SlateUI`) sur le CONTENU du bloc
/// (jamais sur `BlockContainer` lui-meme, voir sa documentation) plutot qu'un simple
/// `.frame(width:)` -- ce dernier resterait plafonne par `EditorContentColumn`, qui
/// enveloppe toute la liste de blocs d'un coup. Voir
/// `EditorController.availableImageAlignments` pour la levee de la restriction
/// correspondante.
struct ImageBlockContentView: View {
    let block: Block
    let editorController: EditorController

    private enum ImportPhase: Equatable {
        case idle
        case importing(fileName: String, sizeText: String)
    }

    @State private var importPhase: ImportPhase = .idle
    @State private var isDropTargeted = false
    @State private var isMenuPresented = false
    /// Palier au debut du geste de redimensionnement EN COURS -- voir `resizeChanged(_:
    /// translation:)`, `DragGesture.translation` est CUMULATIF depuis le debut du
    /// geste, jamais un delta entre deux appels.
    @State private var dragStartAlignment: SlateImageAlignment?

    var body: some View {
        Group {
            switch importPhase {
            case let .importing(fileName, sizeText):
                MediaUploadProgressView(fileName: fileName, fileSizeText: sizeText, progress: 1)
            case .idle:
                if block.attachment?.data != nil {
                    imageFrame
                } else {
                    dropzone
                }
            }
        }
        .padding(.vertical, SlateGeometry.decoratedBlockSpacing)
    }

    // MARK: - Etat vide / survol de depot

    private var dropzone: some View {
        MediaDropzoneView(
            isTargeted: isDropTargeted,
            draggedFileName: nil,
            onChooseFile: presentImagePicker
        )
        .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted, perform: handleDrop)
        .accessibilityAction(named: Text(EditorStrings.fileBlockChooseFile), presentImagePicker)
    }

    // MARK: - Etat affiche/selectionne

    private var isSelected: Bool { editorController.selectedBlockID == block.id }

    private var currentAlignment: SlateImageAlignment {
        SlateImageAlignment(rawValue: block.attributes.imageAlignment ?? "") ?? .left
    }

    private var displayWidth: CGFloat? {
        switch currentAlignment {
        case .left, .center, .right: SlateGeometry.mediaColumnWidth
        case .overflow: SlateGeometry.mediaOverflowWidth
        case .fullWidth: nil
        }
    }

    private var outerAlignment: Alignment {
        switch currentAlignment {
        case .left, .overflow, .fullWidth: .leading
        case .center: .center
        case .right: .trailing
        }
    }

    private var dimensionsText: String {
        guard let attachment = block.attachment else { return "" }
        let name = attachment.filename.isEmpty ? EditorStrings.imageUnnamedFilename : attachment.filename
        guard let width = attachment.width, let height = attachment.height else { return name }
        return "\(name) \u{b7} \(width) \u{d7} \(height)"
    }

    private var captionBinding: Binding<String> {
        Binding(
            get: { block.attributes.imageCaption ?? "" },
            set: { editorController.setImageCaption($0, in: block) }
        )
    }

    private var imageFrame: some View {
        // `Content` specifie explicitement (`AnyView`) : le passer via inference
        // (fermeture `content:` seule) echoue au typechecking en presence des autres
        // fermetures de cet initialiseur (`onResize` notamment, dont le parametre
        // `ImageFrameView<Content>.ResizeHandle` depend structurellement de `Content`
        // meme sans l'utiliser) -- erreur "generic parameter 'Content' could not be
        // inferred" constatee en local, contournee ici plutot qu'en degradant
        // `onResize` a un type non type-sur (`Any`).
        Group {
            if currentAlignment == .overflow || currentAlignment == .fullWidth {
                // Debord hors colonne (Phase 10) : voir la documentation de tete de
                // fichier. `displayWidth` porte deja exactement la cible attendue par
                // `slateBreakOutOfEditorColumn(targetWidth:)` (960 pt, ou `nil` pour
                // "pleine largeur du panneau") pour ces deux paliers.
                framedImage.slateBreakOutOfEditorColumn(targetWidth: displayWidth)
            } else {
                framedImage.frame(width: displayWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: outerAlignment)
        .popover(isPresented: $isMenuPresented) { menuContent }
    }

    private var framedImage: some View {
        ImageFrameView<AnyView>(
            dimensionsText: dimensionsText,
            alignment: currentAlignment,
            isSelected: isSelected,
            caption: captionBinding,
            alignmentOptions: EditorController.availableImageAlignments,
            onSelectAlignment: { editorController.setImageAlignment($0, in: block) },
            onMenu: { isMenuPresented = true },
            onResize: { handle, translation in
                // `handle`/`ImageFrameView<Content>.ResizeHandle` : type INFERE ici
                // (jamais nomme explicitement, voir `applyResize(growth:)`) -- nommer ce
                // type au site d'une fonction independante exigerait de parametrer
                // cette vue par `Content` rien que pour cette signature, voir l'erreur
                // de compilation que ce detour evite ("reference to generic type
                // 'ImageFrameView' requires arguments").
                let growth: CGFloat
                switch handle {
                case .leading: growth = -translation.width
                case .trailing: growth = translation.width
                case .bottom: growth = translation.height
                }
                applyResize(growth: growth)
            },
            onResizeEnded: { _ in dragStartAlignment = nil },
            content: { imageContentView }
        )
    }

    /// Type concret (`AnyView`, pas `some View`) : necessaire pour que `ImageFrameView<
    /// AnyView>` ci-dessus infere correctement son parametre `Content` a travers cette
    /// propriete -- un type opaque a cet endroit echoue au typechecking (constate en
    /// local, voir le commentaire sur `imageFrame`).
    private var imageContentView: AnyView {
        if let data = block.attachment?.data, let nsImage = NSImage(data: data) {
            return AnyView(
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            )
        }
        return AnyView(Rectangle().fill(SlateColor.surfaceTertiary))
    }

    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(EditorStrings.mediaMenuReplace, action: presentImagePicker)
            Button(EditorStrings.mediaMenuDelete, role: .destructive) {
                isMenuPresented = false
                editorController.removeAttachment(from: block)
            }
        }
        .buttonStyle(.plain)
        .padding(Spacing.sm)
    }

    // MARK: - Redimensionnement (poignees, artboard A)

    /// Convertit le geste de redimensionnement en changement de PALIER (pas de largeur
    /// continue, voir `SlateImageAlignment`) : `threshold` points de glissement dans le
    /// sens qui agrandit (`growth` positif) font avancer d'un palier, dans le sens qui
    /// reduit font reculer d'un palier. `growth` derive d'une translation CUMULATIVE
    /// depuis le debut du geste (`DragGesture`), donc compare a `dragStartAlignment`
    /// (fige au premier appel), jamais accumule manuellement ici.
    private func applyResize(growth: CGFloat) {
        if dragStartAlignment == nil { dragStartAlignment = currentAlignment }
        guard let start = dragStartAlignment else { return }
        let all = SlateImageAlignment.allCases
        guard let startIndex = all.firstIndex(of: start) else { return }

        let threshold: CGFloat = 80
        let steps = Int((growth / threshold).rounded(.towardZero))
        let targetIndex = max(0, min(all.count - 1, startIndex + steps))
        let target = all[targetIndex]
        if target != currentAlignment {
            editorController.setImageAlignment(target, in: block)
        }
    }

    // MARK: - Choix de fichier / glisser-depose

    private func presentImagePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importImage(at: url)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in importImage(at: url) }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data else { return }
                Task { @MainActor in importImageData(data) }
            }
            return true
        }
        return false
    }

    /// Decodage/recompression HORS acteur principal (`Task.detached`, qui ne capture
    /// QUE `url`/`data`, tous deux `Sendable` -- ni `block` ni `editorController`, non
    /// `Sendable`, n'y entrent jamais) : une image volumineuse (jusqu'a
    /// `AttachmentService.maxFileSizeBytes`, 2 Go) ne doit jamais geler l'interface.
    /// `Task { @MainActor in ... }` englobant reste, lui, sur l'acteur principal : c'est
    /// la ou `block`/`editorController` sont mutes, comme l'exige `EditorController`.
    private func importImage(at url: URL) {
        let fileName = url.lastPathComponent
        let sizeText = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            .map { AttachmentService().formattedFileSize($0) } ?? ""
        importPhase = .importing(fileName: fileName, sizeText: sizeText)
        Task { @MainActor in
            do {
                let imported = try await Task.detached { try AttachmentService().importImage(fileURL: url) }.value
                editorController.applyImportedImage(imported, into: block)
            } catch {
                editorController.recordAttachmentImportFailure(error, for: block)
            }
            importPhase = .idle
        }
    }

    private func importImageData(_ data: Data) {
        importPhase = .importing(fileName: EditorStrings.imageUnnamedFilename, sizeText: "")
        Task { @MainActor in
            do {
                let imported = try await Task.detached {
                    try AttachmentService().importImage(data: data, filename: "image.png")
                }.value
                editorController.applyImportedImage(imported, into: block)
            } catch {
                editorController.recordAttachmentImportFailure(error, for: block)
            }
            importPhase = .idle
        }
    }
}

import AppKit
import CoreGraphics
import SlateModel
import SlateServices
import SlateUI
import SwiftUI
import UniformTypeIdentifiers

/// Bloc fichier joint (`BlockType.file`, Phase 9, artboard B). Meme absence de
/// `RichText`/`NSTextView` qu'`ImageBlockContentView` (voir sa documentation de tete) --
/// "selectionne", pas "focalise".
///
/// ## Etat vide : aucun artboard dedie
/// Contrairement au bloc image (4 etats, dont un etat "vide/depot" illustre), l'artboard
/// B ne montre qu'un fichier DEJA joint. Un bloc `.file` fraichement insere par `/`
/// (avant tout choix de fichier) n'a donc pas de maquette a reproduire : ce fichier
/// construit une invite minimale, dans le meme langage visuel que
/// `MediaDropzoneView` (memes tokens de geometrie) mais un texte generique ("Ajouter un
/// fichier"), plutot que de reutiliser `MediaDropzoneView` telle quelle (son texte est
/// fige sur "Ajouter une image", non parametrable -- voir sa documentation dans
/// `SlateUI`). Ecart assume, a arbitrer avec un vrai artboard si Cyril en fournit un.
struct FileBlockContentView: View {
    let block: Block
    let editorController: EditorController

    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if block.attachment?.data != nil {
                attachedRow
            } else {
                emptyPrompt
            }
        }
        .padding(.vertical, SlateGeometry.decoratedBlockSpacing)
    }

    // MARK: - Fichier joint (artboard B)

    private var attachedRow: some View {
        let attachment = block.attachment
        let uti = attachment?.uti ?? ""
        let filename = attachment?.filename ?? EditorStrings.imageUnnamedFilename
        let byteCount = attachment?.data?.count ?? 0
        let pageCount = pdfPageCount(uti: uti, data: attachment?.data)
        let typeLabel = AttachmentService().typeLabel(forUTI: uti)
        let sizeText = AttachmentService().formattedFileSize(byteCount)

        let hasMissingData = attachment != nil && attachment?.data == nil
        let importFailure = editorController.attachmentImportFailures[block.id]

        return AttachmentRowView(
            fileType: fileType(forUTI: uti),
            fileName: filename,
            metadata: EditorStrings.attachmentMetadata(typeLabel: typeLabel, sizeText: sizeText, pageCount: pageCount),
            status: importFailure.map { .failedImport(cause: $0) }
                ?? (hasMissingData ? .missing(reason: EditorStrings.attachmentMissingReason) : .normal),
            genericSymbol: genericSymbol(forUTI: uti),
            onPreview: previewFile,
            onDownload: revealInFinder,
            onRetry: presentFilePicker,
            onLocate: presentFilePicker,
            menuItems: {
                Group {
                    Button(EditorStrings.mediaMenuReplace, action: presentFilePicker)
                    Button(EditorStrings.mediaMenuRevealInFinder, action: revealInFinder)
                    Button(EditorStrings.mediaMenuDelete, role: .destructive) {
                        editorController.removeAttachment(from: block)
                    }
                }
            }
        )
    }

    /// Recalcule le nombre de pages a chaque rendu plutot que de le stocker (aucun
    /// champ dedie sur `Attachment`, hors perimetre de cet agent -- voir
    /// `AttachmentService.importFile`, qui fait deja ce calcul a l'import). Cout
    /// negligeable : `CGPDFDocument` ne fait que lire l'en-tete/la table xref, jamais le
    /// contenu des pages.
    private func pdfPageCount(uti: String, data: Data?) -> Int? {
        guard uti == UTType.pdf.identifier, let data,
              let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider)
        else { return nil }
        return document.numberOfPages
    }

    private func fileType(forUTI uti: String) -> SlateAttachmentFileType {
        guard let type = UTType(uti) else { return .generic }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .spreadsheet) { return .spreadsheet }
        return .generic
    }

    private func genericSymbol(forUTI uti: String) -> String {
        guard let type = UTType(uti) else { return "doc" }
        if type.conforms(to: .audio) { return "waveform" }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return "film" }
        if type.conforms(to: .archive) || type.conforms(to: .zip) { return "doc.zipper" }
        if type.conforms(to: .image) { return "photo" }
        return "doc"
    }

    // MARK: - Etat vide (voir la documentation de tete de fichier)

    private var emptyPrompt: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "paperclip")
                .slateIconFont(20, weight: .regular)
                .foregroundStyle(SlateColor.textSecondary)
            Text(EditorStrings.fileBlockEmptyLabel)
                .slateFont(SlateFont.body)
                .foregroundStyle(SlateColor.textPrimary)
            Spacer(minLength: 0)
            Button(EditorStrings.fileBlockChooseFile, action: presentFilePicker)
                .buttonStyle(.plain)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.accentDefault)
                .underline()
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: SlateGeometry.mediaDropzoneHeight)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                .fill(isDropTargeted ? SlateColor.mediaDropzoneActiveBackground : SlateColor.mediaDropzoneBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                .strokeBorder(
                    isDropTargeted ? SlateColor.mediaDropzoneActiveBorder : SlateColor.mediaDropzoneBorder,
                    style: StrokeStyle(lineWidth: SlateGeometry.mediaDropzoneBorderWidth, dash: [5, 3])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
    }

    // MARK: - Actions

    private func previewFile() {
        guard let attachment = block.attachment, let data = attachment.data else { return }
        let url = temporaryFileURL(for: attachment, data: data)
        NSWorkspace.shared.open(url)
    }

    private func revealInFinder() {
        guard let attachment = block.attachment, let data = attachment.data else { return }
        let url = temporaryFileURL(for: attachment, data: data)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// `Attachment.data` n'a pas de fichier sur disque associe (stockage externalise
    /// SwiftData, pas un chemin Finder reel) : "Apercu"/"Reveler dans le Finder"
    /// materialisent une copie TEMPORAIRE pour ces deux actions -- comportement standard
    /// des apps qui stockent leurs pieces jointes en base (ex. Mail.app).
    private func temporaryFileURL(for attachment: Attachment, data: Data) -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(attachment.id.uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(attachment.filename)
        try? data.write(to: url, options: .atomic)
        return url
    }

    private func presentFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        editorController.importAttachedFile(at: url, into: block)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first, provider.canLoadObject(ofClass: URL.self) else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                editorController.importAttachedFile(at: url, into: block)
            }
        }
        return true
    }
}

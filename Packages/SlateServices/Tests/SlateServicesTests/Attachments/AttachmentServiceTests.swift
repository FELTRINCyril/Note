import Foundation
import Testing

@testable import SlateServices

/// Tests de Phase 9 (`docs/09_medias_pieces_jointes.md`) : import/compression
/// d'images, import de fichiers joints, formatage, et refus motives.
struct AttachmentServiceTests {
    private let service = AttachmentService()

    // MARK: - Import image : dimensions et redimensionnement

    @Test
    func importingSmallPNGKeepsOriginalDimensionsAndDoesNotResize() throws {
        let data = ImageFixtures.pngData(width: 200, height: 100)
        let imported = try service.importImage(data: data, filename: "petite.png")

        #expect(imported.width == 200)
        #expect(imported.height == 100)
        #expect(imported.wasResized == false)
    }

    @Test
    func importingOversizedImageIsResizedBelowMaxDimension() throws {
        let data = ImageFixtures.pngData(width: 4_000, height: 2_000)
        let imported = try service.importImage(data: data, filename: "grande.png")

        #expect(imported.wasResized == true)
        #expect(imported.width <= Int(AttachmentService.maxImageDimension))
        #expect(imported.height <= Int(AttachmentService.maxImageDimension))
        // Le ratio d'aspect doit etre preserve (a 1 px pres pour l'arrondi).
        let originalRatio = 4_000.0 / 2_000.0
        let resizedRatio = Double(imported.width) / Double(imported.height)
        #expect(abs(originalRatio - resizedRatio) < 0.02)
    }

    @Test
    func importingOversizedImageActuallyReducesByteCount() throws {
        // Grande image a plat de couleur unie : tres compressible, la recompression
        // JPEG doit reduire nettement le poids par rapport a une source PNG large.
        let data = ImageFixtures.pngData(width: 4_000, height: 3_000)
        let imported = try service.importImage(data: data, filename: "lourde.png")

        #expect(imported.byteCount < imported.originalByteCount)
        #expect(imported.originalByteCount == data.count)
    }

    @Test
    func importingOpaqueImageOutputsJPEG() throws {
        let data = ImageFixtures.pngData(width: 500, height: 400, hasAlpha: false)
        let imported = try service.importImage(data: data, filename: "opaque.png")

        #expect(imported.uti == "public.jpeg")
    }

    @Test
    func importingTransparentImagePreservesPNGOutput() throws {
        let data = ImageFixtures.pngData(width: 500, height: 400, hasAlpha: true)
        let imported = try service.importImage(data: data, filename: "transparente.png")

        #expect(imported.uti == "public.png")
    }

    @Test
    func importingJPEGSucceeds() throws {
        let data = ImageFixtures.jpegData(width: 300, height: 300)
        let imported = try service.importImage(data: data, filename: "photo.jpg")

        #expect(imported.width == 300)
        #expect(imported.height == 300)
    }

    // MARK: - GIF : jamais recompresse

    @Test
    func importingGIFIsNeverResizedOrRecompressedEvenWhenOversized() throws {
        let data = ImageFixtures.gifData(width: 2_400, height: 1_200)
        let imported = try service.importImage(data: data, filename: "anime.gif")

        #expect(imported.wasResized == false)
        #expect(imported.width == 2_400)
        #expect(imported.height == 1_200)
        // Les octets ne sont pas retouches : round-trip identite.
        #expect(imported.data == data)
        #expect(imported.uti == "com.compuserve.gif")
    }

    // MARK: - Refus motives

    @Test
    func importingUnsupportedFormatThrowsWithCause() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        #expect {
            try service.importImage(data: garbage, filename: "inconnu.bin")
        } throws: { error in
            guard case .unsupportedImageFormat = error as? AttachmentImportError else { return false }
            return true
        }
    }

    @Test
    func importingDirectoryIsRefusedExplicitly() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        #expect {
            try service.importFile(fileURL: directoryURL)
        } throws: { error in
            guard case .isDirectory = error as? AttachmentImportError else { return false }
            return true
        }
    }

    @Test
    func importingOversizedFileIsRefusedWithCause() throws {
        // Fichier "creux" (sparse) : sa taille declaree depasse la limite sans qu'on
        // ecrive reellement les octets sur le disque, le test reste rapide et leger.
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.truncate(atOffset: UInt64(AttachmentService.maxFileSizeBytes) + 1)
        try handle.close()

        #expect {
            try service.importFile(fileURL: fileURL)
        } throws: { error in
            guard case let .fileTooLarge(_, actualBytes, maxBytes) = error as? AttachmentImportError else {
                return false
            }
            return actualBytes > maxBytes
        }
    }

    @Test
    func fileTooLargeErrorDescriptionNamesTheCause() {
        // `errorDescription` seul suit `.current` (correct en production, voir sa
        // documentation) -- donc non deterministe pour un test : on passe par
        // `AttachmentImportError.description(for:locale:)`, qui fige la locale, meme
        // motif que `formattedFileSize(_:locale:)`.
        let error = AttachmentImportError.fileTooLarge(
            name: "montage-final.mov",
            actualBytes: 3 * 1_000_000_000,
            maxBytes: AttachmentService.maxFileSizeBytes
        )
        let french = AttachmentImportError.description(for: error, locale: Locale(identifier: "fr_FR"))
        #expect(french.contains("montage-final.mov"))
        #expect(french.contains("Go"))

        let english = AttachmentImportError.description(for: error, locale: Locale(identifier: "en_US"))
        #expect(english.contains("montage-final.mov"))
        #expect(english.contains("GB"))
    }

    // MARK: - Import fichier non-image

    @Test
    func importingArbitraryFileCapturesNameUTIAndSize() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        let content = Data("Contenu de test.".utf8)
        try content.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let imported = try service.importFile(fileURL: fileURL)
        #expect(imported.filename == fileURL.lastPathComponent)
        #expect(imported.data == content)
        #expect(imported.pageCount == nil)
        #expect(imported.durationSeconds == nil)
    }

    @Test
    func importingPDFExtractsPageCount() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pdf")
        try PDFFixtures.twoPagePDFData().write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let imported = try service.importFile(fileURL: fileURL)
        #expect(imported.pageCount == 2)
    }

    // MARK: - Formatage

    /// Les valeurs attendues sont celles ecrites dans l'artboard B du design
    /// ("1,8 Mo", "148 Ko", "64,9 Mo"). La locale est INJECTEE : c'est de la que vient
    /// le determinisme du test, la production suit `.current` (voir le commentaire de
    /// `formattedFileSize`).
    @Test
    func formattedFileSizeUsesFrenchDecimalCommaAndUnits() {
        let french = Locale(identifier: "fr_FR")
        #expect(service.formattedFileSize(148_000, locale: french) == "148 Ko")
        #expect(service.formattedFileSize(1_800_000, locale: french) == "1,8 Mo")
        #expect(service.formattedFileSize(64_900_000, locale: french) == "64,9 Mo")
        #expect(service.formattedFileSize(500, locale: french) == "500 octets")
        #expect(service.formattedFileSize(1, locale: french) == "1 octet")
    }

    /// L'app est localisee FR + EN : un utilisateur anglais doit lire "1.8 MB", pas
    /// "1,8 Mo". Ce test existe parce que la premiere version figeait `fr_FR` en
    /// production, ce qui rendait ce cas impossible.
    @Test
    func formattedFileSizeFollowsEnglishLocale() {
        let english = Locale(identifier: "en_US")
        #expect(service.formattedFileSize(148_000, locale: english) == "148 KB")
        #expect(service.formattedFileSize(1_800_000, locale: english) == "1.8 MB")
        #expect(service.formattedFileSize(500, locale: english) == "500 bytes")
        #expect(service.formattedFileSize(1, locale: english) == "1 byte")
    }

    @Test
    func typeLabelsMatchDesign() {
        let french = Locale(identifier: "fr_FR")
        #expect(service.typeLabel(forUTI: "com.adobe.pdf", locale: french) == "PDF")
        #expect(service.typeLabel(forUTI: "org.openxmlformats.spreadsheetml.sheet", locale: french) == "Tableur")
        #expect(service.typeLabel(forUTI: "public.mp3", locale: french) == "Audio")
        #expect(service.typeLabel(forUTI: "public.zip-archive", locale: french) == "Archive")
        #expect(service.typeLabel(forUTI: "public.jpeg", locale: french) == "Image")
        #expect(service.typeLabel(forUTI: "not.a.real.uti", locale: french) == "Document")
    }

    @Test
    func typeLabelsFollowEnglishLocale() {
        let english = Locale(identifier: "en_US")
        #expect(service.typeLabel(forUTI: "com.adobe.pdf", locale: english) == "PDF")
        #expect(service.typeLabel(forUTI: "org.openxmlformats.spreadsheetml.sheet", locale: english) == "Spreadsheet")
        #expect(service.typeLabel(forUTI: "public.mp3", locale: english) == "Audio")
        #expect(service.typeLabel(forUTI: "public.zip-archive", locale: english) == "Archive")
        #expect(service.typeLabel(forUTI: "public.jpeg", locale: english) == "Image")
        #expect(service.typeLabel(forUTI: "not.a.real.uti", locale: english) == "Document")
    }
}

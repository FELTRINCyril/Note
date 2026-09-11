import CoreGraphics
import Foundation
import ImageIO
import SlateModel
import SwiftData
import UniformTypeIdentifiers

/// Resultat d'un import d'image reussi, pret a alimenter un `Attachment`.
public struct ImportedImage: Sendable, Equatable {
    public let filename: String
    public let uti: String
    public let data: Data
    public let width: Int
    public let height: Int
    public let originalByteCount: Int
    public let wasResized: Bool

    public var byteCount: Int { data.count }
}

/// Resultat d'un import de fichier joint reussi (non-image), pret a alimenter un
/// `Attachment`.
public struct ImportedFile: Sendable, Equatable {
    public let filename: String
    public let uti: String
    public let data: Data

    /// Nombre de pages, uniquement pour un PDF. `nil` sinon, ou si l'extraction a
    /// echoue (document corrompu) : jamais une valeur devinee.
    public let pageCount: Int?

    /// Duree en secondes pour un fichier audio/video. Toujours `nil` dans cette phase
    /// (voir `AttachmentService.importFile(fileURL:)`) : non extraite plutot
    /// qu'approximee.
    public let durationSeconds: Double?

    public var byteCount: Int { data.count }
}

/// Import, compression, formatage et suppression des pieces jointes (`Attachment`).
///
/// Aucune gestion manuelle de `CKAsset` ici : `Attachment.data` est deja marque
/// `@Attribute(.externalStorage)` (phase 2), SwiftData traduit lui-meme ce marquage en
/// `CKAsset` lors de la synchronisation CloudKit. Ce service ne fait que produire des
/// `Data` deja bornees en poids et les metadonnees qui vont avec ; c'est l'appelant
/// (cote UI/persistance) qui construit l'`Attachment` et l'insere dans le contexte.
public struct AttachmentService: Sendable {
    /// Cote le plus long autorise pour une image importee (PNG/JPEG/HEIC), en pixels.
    ///
    /// Le palier de largeur "debord" du bloc image vaut 960 pt
    /// (`media.overflowWidth`, design artboard D). A l'echelle Retina la plus courante
    /// (2x), cela represente 1920 px de large affiches. 2000 px de cote le plus long
    /// couvre ce cas avec une petite marge (orientation portrait, ou un affichage
    /// partiel a 3x), sans stocker les originaux a pleine resolution capteur : un
    /// appareil photo recent produit facilement 4000-6000 px de cote, ce qui
    /// alourdirait le store et la synchronisation CloudKit pour un gain visuel nul
    /// au-dela de la taille d'affichage maximale de l'app.
    public static let maxImageDimension: CGFloat = 2_000

    /// Qualite de compression JPEG appliquee a la recompression.
    ///
    /// 0.72 est un compromis standard : au-dela de 0.8 le gain visuel devient marginal
    /// par rapport au cout en poids ; en dessous de 0.6 les artefacts de compression
    /// deviennent visibles sur des captures d'ecran/schemas a aplats nets, un cas
    /// frequent dans une app de prise de notes.
    public static let jpegCompressionQuality: CGFloat = 0.72

    /// Taille de fichier maximale acceptee a l'import, tous types confondus. Reprend
    /// le seuil illustre par le design (artboard B : "fichier superieur a 2 Go").
    public static let maxFileSizeBytes: Int64 = 2 * 1_024 * 1_024 * 1_024

    /// Formats d'image acceptes a l'import (`docs/09_medias_pieces_jointes.md`).
    private static let acceptedImageTypes: [UTType] = [.png, .jpeg, .heic, .gif]

    public init() {}

    // MARK: - Import image

    /// Importe une image depuis un fichier sur disque.
    public func importImage(fileURL: URL) throws -> ImportedImage {
        let name = fileURL.lastPathComponent
        try Self.validateRegularFile(at: fileURL, name: name)
        try Self.validateFileSize(at: fileURL, name: name)
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw AttachmentImportError.unreadableFile(name: name)
        }
        return try importImage(data: data, filename: name)
    }

    /// Importe une image depuis des octets bruts (glisser-deposer, coller, ou lecture
    /// de fichier deja faite par l'appelant).
    ///
    /// Redimensionne et recompresse l'image si elle depasse `maxImageDimension`, sauf
    /// pour un GIF (voir le commentaire dans le corps de la fonction). Le format de
    /// sortie est PNG si l'image a un canal alpha (pour ne pas detruire la
    /// transparence), JPEG sinon.
    public func importImage(data: Data, filename: String) throws -> ImportedImage {
        guard Int64(data.count) <= Self.maxFileSizeBytes else {
            throw AttachmentImportError.fileTooLarge(
                name: filename,
                actualBytes: Int64(data.count),
                maxBytes: Self.maxFileSizeBytes
            )
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let sourceUTIString = CGImageSourceGetType(source) as String?,
            let sourceType = UTType(sourceUTIString)
        else {
            throw AttachmentImportError.unsupportedImageFormat(uti: nil)
        }
        guard Self.acceptedImageTypes.contains(where: { sourceType.conforms(to: $0) }) else {
            throw AttachmentImportError.unsupportedImageFormat(uti: sourceUTIString)
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let originalWidth = properties[kCGImagePropertyPixelWidth] as? Int,
            let originalHeight = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            throw AttachmentImportError.unsupportedImageFormat(uti: sourceUTIString)
        }

        // Les GIF ne sont jamais recompresses/redimensionnes : un `CGImageDestination`
        // n'encode qu'une seule image, donc repasser un GIF par ce pipeline
        // detruirait silencieusement ses frames d'animation (on obtiendrait un GIF
        // valide, mais fige sur la premiere frame, sans aucune erreur pour le
        // signaler). Un GIF trop lourd est deja rejete par la verification de taille
        // ci-dessus, comme tout autre fichier.
        if sourceType.conforms(to: .gif) {
            return ImportedImage(
                filename: filename,
                uti: sourceUTIString,
                data: data,
                width: originalWidth,
                height: originalHeight,
                originalByteCount: data.count,
                wasResized: false
            )
        }

        let wasResized = CGFloat(max(originalWidth, originalHeight)) > Self.maxImageDimension
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: Self.maxImageDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let outputImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw AttachmentImportError.unsupportedImageFormat(uti: sourceUTIString)
        }

        let outputType: UTType = Self.imageHasAlpha(outputImage) ? .png : .jpeg
        let outputData = try Self.encode(outputImage, as: outputType, quality: Self.jpegCompressionQuality)

        return ImportedImage(
            filename: filename,
            uti: outputType.identifier,
            data: outputData,
            width: outputImage.width,
            height: outputImage.height,
            originalByteCount: data.count,
            wasResized: wasResized
        )
    }

    private static func imageHasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            return true
        }
    }

    private static func encode(_ image: CGImage, as type: UTType, quality: CGFloat) throws -> Data {
        let mutableData = NSMutableData()
        let destinationUTI = type.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(mutableData, destinationUTI, 1, nil) else {
            throw AttachmentImportError.unsupportedImageFormat(uti: type.identifier)
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw AttachmentImportError.unsupportedImageFormat(uti: type.identifier)
        }
        return mutableData as Data
    }

    // MARK: - Import fichier

    /// Importe un fichier joint quelconque (non-image) depuis un fichier sur disque.
    /// Extrait le nombre de pages pour un PDF (peu couteux, `CGPDFDocument`). N'extrait
    /// pas la duree d'un fichier audio/video : `AVAsset.load(.duration)` est
    /// asynchrone et introduirait une dependance a AVFoundation disproportionnee pour
    /// cette phase ; le champ reste `nil` plutot que d'afficher une duree fausse.
    public func importFile(fileURL: URL) throws -> ImportedFile {
        let name = fileURL.lastPathComponent
        try Self.validateRegularFile(at: fileURL, name: name)
        try Self.validateFileSize(at: fileURL, name: name)
        let resourceValues = try? fileURL.resourceValues(forKeys: [.contentTypeKey])

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw AttachmentImportError.unreadableFile(name: name)
        }
        guard Int64(data.count) <= Self.maxFileSizeBytes else {
            throw AttachmentImportError.fileTooLarge(
                name: name,
                actualBytes: Int64(data.count),
                maxBytes: Self.maxFileSizeBytes
            )
        }

        let type = resourceValues?.contentType ?? UTType(filenameExtension: fileURL.pathExtension) ?? .data
        return ImportedFile(
            filename: name,
            uti: type.identifier,
            data: data,
            pageCount: Self.pdfPageCount(data: data, type: type),
            durationSeconds: nil
        )
    }

    private static func pdfPageCount(data: Data, type: UTType) -> Int? {
        guard type.conforms(to: .pdf) else { return nil }
        guard let provider = CGDataProvider(data: data as CFData),
            let document = CGPDFDocument(provider)
        else { return nil }
        return document.numberOfPages
    }

    private static func validateRegularFile(at url: URL, name: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw AttachmentImportError.unreadableFile(name: name)
        }
        if isDirectory.boolValue {
            throw AttachmentImportError.isDirectory(name: name)
        }
    }

    /// Verifie la taille du fichier sur disque via ses metadonnees, sans le lire :
    /// un fichier trop volumineux doit etre refuse avant d'etre charge en memoire, pas
    /// apres.
    private static func validateFileSize(at url: URL, name: String) throws {
        guard let sizeOnDisk = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return
        }
        guard Int64(sizeOnDisk) <= Self.maxFileSizeBytes else {
            throw AttachmentImportError.fileTooLarge(
                name: name,
                actualBytes: Int64(sizeOnDisk),
                maxBytes: Self.maxFileSizeBytes
            )
        }
    }

    // MARK: - Suppression

    /// Supprime proprement la piece jointe d'un bloc : detache la relation et supprime
    /// l'entite `Attachment` du contexte (et donc son binaire externalise).
    ///
    /// Important : se contenter de `block.attachment = nil` detache la relation mais
    /// ne supprime pas la ligne `Attachment`, qui reste alors orpheline dans le store
    /// (meme classe de bug que les blocs detaches-mais-jamais-supprimes corriges en
    /// phase 8, voir `AttachmentOrphanTests`). Le `deleteRule: .cascade` sur
    /// `Block.attachment` ne joue que quand le `Block` porteur lui-meme est supprime,
    /// pas quand on vide seulement la relation.
    @MainActor
    public func removeAttachment(from block: Block, in context: ModelContext) {
        guard let attachment = block.attachment else { return }
        block.attachment = nil
        context.delete(attachment)
    }

    /// Remplace la piece jointe d'un bloc par une nouvelle, en supprimant proprement
    /// l'ancienne (voir `removeAttachment(from:in:)`).
    @MainActor
    public func replaceAttachment(of block: Block, with newAttachment: Attachment, in context: ModelContext) {
        // Detacher puis supprimer l'ancienne piece jointe *avant* de brancher la
        // nouvelle : `context.delete` sur un objet encore reference par la relation
        // laisse SwiftData tenter de refleter ce retrait sur un objet dont les donnees
        // sont deja supprimees (crash "Never access a full future backing data"),
        // constate en test. Le meme ordre que `removeAttachment(from:in:)` evite ce
        // piege.
        if let old = block.attachment {
            block.attachment = nil
            context.delete(old)
        }
        newAttachment.block = block
        block.attachment = newAttachment
        context.insert(newAttachment)
    }

    // MARK: - Formatage

    /// Taille lisible ("1,8 Mo", "148 Ko"...), chiffres suivis de l'unite en toutes
    /// lettres comme dans le design.
    ///
    /// `ByteCountFormatter` a ete ecarte : il ne permet pas de choisir sa locale (elle
    /// suit toujours celle du systeme), donc le resultat serait impossible a fixer dans
    /// un test. On garde `NumberFormatter` (Foundation) pour la partie numerique, et la
    /// mise a l'echelle Ko/Mo/Go plus le suffixe sont ecrits a la main.
    ///
    /// La locale est un PARAMETRE, defaut `.current`. L'app est localisee FR + EN
    /// (`CLAUDE.md` §5) : figer `fr_FR` ici afficherait "1,8 Mo" a un utilisateur
    /// anglais, la ou il attend "1.8 MB". Le determinisme dont un test a besoin vient
    /// donc de la locale qu'il injecte, jamais d'une locale figee en production.
    public func formattedFileSize(_ bytes: Int, locale: Locale = .current) -> String {
        Self.formattedSize(bytes: Int64(bytes), locale: locale)
    }

    /// Palier d'unite et son libelle dans les deux langues de l'app. Le systeme
    /// metrique est le meme en francais et en anglais, seul le libelle change.
    /// (Structure et non tuple : `large_tuple` de `.swiftlint.yml` limite a 2 membres.)
    private struct SizeUnit {
        let french: String
        let english: String
        let threshold: Double

        /// Du plus grand au plus petit : la premiere unite atteinte est la bonne.
        static let descending: [SizeUnit] = [
            SizeUnit(french: "Go", english: "GB", threshold: 1_000_000_000),
            SizeUnit(french: "Mo", english: "MB", threshold: 1_000_000),
            SizeUnit(french: "Ko", english: "KB", threshold: 1_000)
        ]
    }

    static func formattedSize(bytes: Int64, locale: Locale = .current) -> String {
        let isFrench = locale.language.languageCode?.identifier == "fr"
        for unit in SizeUnit.descending where Double(bytes) >= unit.threshold {
            let value = Double(bytes) / unit.threshold
            let suffix = isFrench ? unit.french : unit.english
            return "\(formatDecimal(value, locale: locale)) \(suffix)"
        }
        if isFrench {
            return bytes <= 1 ? "\(bytes) octet" : "\(bytes) octets"
        }
        return bytes <= 1 ? "\(bytes) byte" : "\(bytes) bytes"
    }

    private static func formatDecimal(_ value: Double, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    /// Libelle de type lisible pour un UTI ("PDF", "Tableur"/"Spreadsheet",
    /// "Audio"...), voir `AttachmentTypeLabel`. Meme parametre `locale` explicite que
    /// `formattedFileSize(_:locale:)`, pour la meme raison (defaut `.current` en
    /// production, locale figee possible en test).
    public func typeLabel(forUTI uti: String, locale: Locale = .current) -> String {
        AttachmentTypeLabel.label(forUTI: uti, locale: locale)
    }
}

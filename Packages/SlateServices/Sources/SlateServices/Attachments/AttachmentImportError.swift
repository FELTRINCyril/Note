import Foundation

/// Echec d'import d'une image ou d'une piece jointe, avec sa cause explicite.
///
/// Le design (artboard B, "Echec de l'import - fichier superieur a 2 Go") exige que
/// toute erreur d'import nomme sa cause a l'utilisateur : ce type porte cette cause de
/// facon structuree (pas un `String` libre) pour que l'UI puisse a la fois afficher un
/// message localise et, si besoin, adapter son comportement (ex. proposer "Reessayer"
/// pour une taille depassee, mais pas pour un dossier depose).
public enum AttachmentImportError: Error, Equatable, Sendable {
    /// L'element depose est un dossier, pas un fichier. Le design impose un refus
    /// explicite ("un dossier depose est refuse avec un message, pas ignore
    /// silencieusement"), jamais un import silencieux du dossier ou de son contenu.
    case isDirectory(name: String)

    /// Le fichier depasse `AttachmentService.maxFileSizeBytes`.
    case fileTooLarge(name: String, actualBytes: Int64, maxBytes: Int64)

    /// Le fichier source est introuvable ou illisible (permissions, chemin invalide).
    case unreadableFile(name: String)

    /// Les octets fournis ne correspondent a aucun format d'image reconnu par
    /// `ImageIO`, ou a un format d'image non pris en charge par l'import image
    /// (seuls PNG, JPEG, HEIC et GIF sont acceptes, voir `docs/09_medias_pieces_jointes.md`).
    case unsupportedImageFormat(uti: String?)
}

extension AttachmentImportError: LocalizedError {
    /// `LocalizedError.errorDescription` n'a pas de parametre : cette exigence du
    /// protocole affiche donc toujours le message dans la langue COURANTE de
    /// l'utilisateur (`.current`), ce qui est le comportement correct en production --
    /// contrairement a `description(locale:)` ci-dessous, qui existe uniquement pour
    /// qu'un test puisse figer la langue attendue independamment de la machine qui
    /// l'execute (meme raison que `AttachmentService.formattedFileSize(_:locale:)`).
    public var errorDescription: String? {
        Self.description(for: self, locale: .current)
    }

    /// Message localise (FR/EN -- CLAUDE.md §5) pour `error`, dans la langue de
    /// `locale`. Avant cette correction, ces messages etaient des phrases francaises
    /// figees : un utilisateur macOS en anglais aurait lu un message d'erreur
    /// entierement en francais, y compris l'unite de taille de fichier (deja corrigee
    /// separement sur `formattedFileSize`, mais pas la phrase qui l'entoure).
    static func description(for error: AttachmentImportError, locale: Locale) -> String {
        let isFrench = locale.language.languageCode?.identifier == "fr"
        switch error {
        case let .isDirectory(name):
            return isFrench
                ? "\"\(name)\" est un dossier : deposez un fichier."
                : "\"\(name)\" is a folder: drop a file instead."
        case let .fileTooLarge(name, actualBytes, maxBytes):
            let actual = AttachmentService.formattedSize(bytes: actualBytes, locale: locale)
            let max = AttachmentService.formattedSize(bytes: maxBytes, locale: locale)
            return isFrench
                ? "\"\(name)\" (\(actual)) depasse la taille maximale autorisee (\(max))."
                : "\"\(name)\" (\(actual)) exceeds the maximum allowed size (\(max))."
        case let .unreadableFile(name):
            return isFrench
                ? "\"\(name)\" est introuvable ou illisible."
                : "\"\(name)\" could not be found or read."
        case let .unsupportedImageFormat(uti):
            if let uti {
                return isFrench
                    ? "Format d'image non pris en charge (\(uti))."
                    : "Unsupported image format (\(uti))."
            }
            return isFrench ? "Format d'image non reconnu." : "Unrecognized image format."
        }
    }
}

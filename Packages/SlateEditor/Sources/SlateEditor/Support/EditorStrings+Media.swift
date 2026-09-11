import Foundation
import SlateModel

/// Chaines des blocs media (Phase 9, docs/09_medias_pieces_jointes.md : image, fichier
/// joint) -- extrait de `EditorStrings.swift` pour rester sous la limite de longueur de
/// fichier de `CLAUDE.md` §5, meme motif exact que `EditorStrings+SpecialBlocks.swift`
/// (Phase 8). Meme type (`EditorStrings`), aucune nouvelle surface publique qui lui soit
/// propre.
extension EditorStrings {
    /// Libelle du type de bloc `.image`/`.file`, extrait de `blockTypeLabel(_:)` pour
    /// rester sous la limite de complexite cyclomatique de SwiftLint -- meme raison et
    /// meme motif que `headingTypeLabel(_:)`.
    static func mediaTypeLabel(_ type: BlockType) -> String? {
        switch type {
        case .image:
            String(localized: "editor.blockType.image", bundle: .module)
        case .file:
            String(localized: "editor.blockType.file", bundle: .module)
        default:
            nil
        }
    }

    /// Sous-titre de la commande "/" `.image`/`.file`, extrait de
    /// `slashCommandSubtitle(_:)` -- meme motif que `mediaTypeLabel(_:)` ci-dessus.
    static func mediaSlashCommandSubtitle(_ type: BlockType) -> String? {
        switch type {
        case .image:
            String(localized: "editor.slashCommand.subtitle.image", bundle: .module)
        case .file:
            String(localized: "editor.slashCommand.subtitle.file", bundle: .module)
        default:
            nil
        }
    }

    static var mediaMenuReplace: String { String(localized: "editor.media.menu.replace", bundle: .module) }
    static var mediaMenuRename: String { String(localized: "editor.media.menu.rename", bundle: .module) }
    static var mediaMenuRevealInFinder: String {
        String(localized: "editor.media.menu.revealInFinder", bundle: .module)
    }
    static var mediaMenuDelete: String { String(localized: "editor.media.menu.delete", bundle: .module) }

    /// Libelle du bloc fichier tant qu'aucun fichier n'a encore ete choisi (etat sans
    /// artboard dedie -- voir la documentation de tete de `FileBlockContentView`).
    static var fileBlockEmptyLabel: String { String(localized: "editor.media.file.emptyLabel", bundle: .module) }
    static var fileBlockChooseFile: String { String(localized: "editor.media.file.chooseFile", bundle: .module) }

    /// Metadonnees d'une piece jointe deja importee ("PDF - 2,4 Mo - 12 pages"),
    /// `pageCount` `nil` pour tout ce qui n'est pas un PDF (voir `FileBlockContentView`).
    static func attachmentMetadata(typeLabel: String, sizeText: String, pageCount: Int?) -> String {
        if let pageCount {
            let template = String(localized: "editor.media.file.metadata.withPages", bundle: .module)
            return String(format: template, typeLabel, sizeText, pageCount)
        }
        let template = String(localized: "editor.media.file.metadata", bundle: .module)
        return String(format: template, typeLabel, sizeText)
    }

    static var attachmentMissingReason: String {
        String(localized: "editor.media.file.missingReason", bundle: .module)
    }

    /// Repli affiche a la place du nom de fichier quand celui-ci est vide -- ne devrait
    /// arriver que sur une donnee corrompue, garde-fou plutot qu'un texte vide.
    static var imageUnnamedFilename: String {
        String(localized: "editor.media.image.unnamedFilename", bundle: .module)
    }
}

import Foundation
import UniformTypeIdentifiers

/// Resout un UTI vers un libelle de type lisible, en francais, tel qu'affiche par le
/// design (artboard B : "PDF", "Tableur", "Audio", "Archive"...). Le design impose que
/// le type soit "toujours ecrit en clair" a cote de la pastille d'icone : la couleur
/// seule n'est jamais l'unique indication (accessibilite, daltonisme).
///
/// Verifie par conformite `UTType` plutot que par correspondance exacte de chaine :
/// une meme famille de fichiers a plusieurs UTI selon la source (ex. plusieurs UTI de
/// tableur bureautique), et `conforms(to:)` les couvre tous sans enumeration exhaustive
/// fragile.
public enum AttachmentTypeLabel {
    /// Libelle et sa traduction anglaise -- meme motif que `AttachmentService.SizeUnit`
    /// (structure plutot que tuple, `large_tuple` de `.swiftlint.yml` limite a 2
    /// membres).
    private struct Label {
        let french: String
        let english: String
    }

    /// Libelle lisible pour un UTI donne, dans la langue de `locale` (par defaut celle
    /// de l'utilisateur -- CLAUDE.md §5, l'app est localisee FR + EN, ce libelle etait
    /// jusqu'ici fige en francais quel que soit le systeme). Retombe sur "Document"/
    /// "Document" si l'UTI est absent, invalide, ou ne correspond a aucune famille
    /// connue : mieux vaut un libelle generique honnete qu'une supposition fausse.
    ///
    /// `locale` est un PARAMETRE explicite (pas juste `.current` en interne) pour la
    /// meme raison que `AttachmentService.formattedFileSize(_:locale:)` : un test doit
    /// pouvoir figer la langue attendue independamment de la locale de la machine qui
    /// l'execute.
    public static func label(forUTI uti: String, locale: Locale = .current) -> String {
        let isFrench = locale.language.languageCode?.identifier == "fr"
        guard let type = UTType(uti) else { return "Document" }

        let label: Label
        if type.conforms(to: .pdf) {
            label = Label(french: "PDF", english: "PDF")
        } else if type.conforms(to: .spreadsheet) {
            label = Label(french: "Tableur", english: "Spreadsheet")
        } else if type.conforms(to: .presentation) {
            label = Label(french: "Presentation", english: "Presentation")
        } else if type.conforms(to: .archive) || type.conforms(to: .zip) {
            label = Label(french: "Archive", english: "Archive")
        } else if type.conforms(to: .audio) {
            label = Label(french: "Audio", english: "Audio")
        } else if type.conforms(to: .movie) {
            label = Label(french: "Video", english: "Video")
        } else if type.conforms(to: .image) {
            label = Label(french: "Image", english: "Image")
        } else if type.conforms(to: .plainText) || type.conforms(to: .text) {
            label = Label(french: "Texte", english: "Text")
        } else {
            label = Label(french: "Document", english: "Document")
        }
        return isFrench ? label.french : label.english
    }
}

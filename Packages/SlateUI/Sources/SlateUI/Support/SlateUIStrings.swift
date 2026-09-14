import Foundation

/// Chaines visibles PORTEES PAR `SlateUI` LUI-MEME (`Bundle.module`), meme motif que
/// `EditorStrings` dans `SlateEditor` (voir sa documentation de tete pour le contexte
/// historique -- ce module a rejoint le meme motif a la dette technique de fin de
/// jalon v1, `SlateUI` n'ayant auparavant AUCUN catalogue de localisation).
///
/// Centralise ICI toute nouvelle chaine visible de `SlateUI` plutot que de la laisser
/// en litteral dans une vue : c'est la seule facon de garantir qu'elle est a la fois
/// localisee (FR + EN) et orthographiee correctement (accents compris -- important pour
/// les `accessibilityLabel`/`accessibilityValue`, que VoiceOver PRONONCE a voix haute).
///
/// PIEGE A NE JAMAIS ROUVRIR : ne jamais interpoler une valeur dans le `defaultValue`
/// d'un `String(localized:defaultValue:)`, et ne jamais construire une cle de catalogue
/// par interpolation -- `Localizable.xcstrings` n'extrait que des cles CONSTANTES.
/// Toute chaine avec une valeur variable passe par un gabarit localise CONSTANT
/// (`%lld`/`%@`) consomme via `String(format:)`, jamais par une interpolation Swift
/// directe dans la cle ou le defaut (voir `EditorStrings.blockMenuSelectionSummary(_:)`
/// dans `SlateEditor` pour l'exemple canonique de ce correctif).
enum SlateUIStrings {
    // MARK: - DisclosureChevron

    static var disclosureChevronExpand: String {
        String(localized: "ui.disclosureChevron.expand", bundle: .module)
    }

    static var disclosureChevronCollapse: String {
        String(localized: "ui.disclosureChevron.collapse", bundle: .module)
    }

    // MARK: - AttachmentRowView

    static var attachmentRetry: String { String(localized: "ui.attachment.retry", bundle: .module) }
    static var attachmentLocate: String { String(localized: "ui.attachment.locate", bundle: .module) }
    static var attachmentPreview: String { String(localized: "ui.attachment.preview", bundle: .module) }
    static var attachmentDownload: String { String(localized: "ui.attachment.download", bundle: .module) }
    static var attachmentOptions: String { String(localized: "ui.attachment.options", bundle: .module) }

    // MARK: - BlockContainer

    /// Placeholder par defaut d'un bloc paragraphe vide (`BlockContainer.init`).
    /// `SlateEditor` passe systematiquement sa PROPRE valeur localisee
    /// (`EditorStrings.paragraphPlaceholder`) -- ce defaut n'est donc reellement visible
    /// que dans les previews/tests internes a `SlateUI`, mais reste localise par
    /// coherence (jamais de litteral fige dans une API publique).
    static var blockParagraphPlaceholder: String {
        String(localized: "ui.block.paragraphPlaceholder", bundle: .module)
    }

    // MARK: - BlockHandle

    static var blockHandleInsertLabel: String { String(localized: "ui.blockHandle.insert.label", bundle: .module) }
    static var blockHandleInsertHelp: String { String(localized: "ui.blockHandle.insert.help", bundle: .module) }
    static var blockHandleMenuLabel: String { String(localized: "ui.blockHandle.menu.label", bundle: .module) }
    static var blockHandleMenuHelp: String { String(localized: "ui.blockHandle.menu.help", bundle: .module) }

    // MARK: - CalloutTokens

    static var calloutInfo: String { String(localized: "ui.callout.info", bundle: .module) }
    static var calloutWarning: String { String(localized: "ui.callout.warning", bundle: .module) }
    static var calloutSuccess: String { String(localized: "ui.callout.success", bundle: .module) }

    // MARK: - ChecklistItemView

    static var checklistLabel: String { String(localized: "ui.checklist.label", bundle: .module) }
    static var checklistDone: String { String(localized: "ui.checklist.done", bundle: .module) }
    static var checklistTodo: String { String(localized: "ui.checklist.todo", bundle: .module) }

    // MARK: - CodeBlockToolbar

    static var codeBlockLanguage: String { String(localized: "ui.codeBlock.language", bundle: .module) }
    static var codeBlockCopy: String { String(localized: "ui.codeBlock.copy", bundle: .module) }
    static var codeBlockCopied: String { String(localized: "ui.codeBlock.copied", bundle: .module) }

    // MARK: - ColumnsBlockView

    /// Libelle d'accessibilite du separateur entre les colonnes `index` et `index + 1`
    /// (1-based dans le libelle, comme l'original). Cle a gabarit CONSTANT (`%lld` deux
    /// fois) -- voir la documentation de tete pour la raison.
    static func columnsResizerLabel(_ first: Int, _ second: Int) -> String {
        let template = String(localized: "ui.columns.resizerLabel", bundle: .module)
        return String(format: template, first, second)
    }

    // MARK: - DividerBlockView

    static var dividerLabel: String { String(localized: "ui.divider.label", bundle: .module) }

    // MARK: - ImageFrameView

    static var imageCaptionPlaceholder: String { String(localized: "ui.image.captionPlaceholder", bundle: .module) }
    static var imageOptions: String { String(localized: "ui.image.options", bundle: .module) }
    static var imageResize: String { String(localized: "ui.image.resize", bundle: .module) }

    // MARK: - MediaDropOverlays

    static var mediaDropIndicatorItemLabelDefault: String {
        String(localized: "ui.media.dropIndicator.itemLabelDefault", bundle: .module)
    }

    static func mediaDropIndicatorInsertMultiple(count: Int, itemLabel: String) -> String {
        let template = String(localized: "ui.media.dropIndicator.insertMultiple", bundle: .module)
        return String(format: template, count, itemLabel)
    }

    static var mediaDropIndicatorInsertSingle: String {
        String(localized: "ui.media.dropIndicator.insertSingle", bundle: .module)
    }

    static func mediaNoteDropTitle(destinationTitle: String) -> String {
        let template = String(localized: "ui.media.noteDrop.title", bundle: .module)
        return String(format: template, destinationTitle)
    }

    // MARK: - MediaDropzoneView

    static var mediaDropzoneAddImage: String { String(localized: "ui.media.dropzone.addImage", bundle: .module) }
    static var mediaDropzoneInstructions: String {
        String(localized: "ui.media.dropzone.instructions", bundle: .module)
    }
    static var mediaDropzoneChooseOnMac: String {
        String(localized: "ui.media.dropzone.chooseOnMac", bundle: .module)
    }
    static var mediaDropzoneDropHere: String { String(localized: "ui.media.dropzone.dropHere", bundle: .module) }

    static func mediaDropzoneDropNamed(_ fileName: String) -> String {
        let template = String(localized: "ui.media.dropzone.dropNamed", bundle: .module)
        return String(format: template, fileName)
    }

    // MARK: - MediaUploadProgressView

    static var mediaUploadCancel: String { String(localized: "ui.media.upload.cancel", bundle: .module) }

    // MARK: - QuoteBlockView

    static var quoteLabel: String { String(localized: "ui.quote.label", bundle: .module) }

    // MARK: - SlateImageAlignment

    static func imageAlignmentLabel(_ alignment: SlateImageAlignment) -> String {
        switch alignment {
        case .left: String(localized: "ui.imageAlignment.left.label", bundle: .module)
        case .center: String(localized: "ui.imageAlignment.center.label", bundle: .module)
        case .right: String(localized: "ui.imageAlignment.right.label", bundle: .module)
        case .overflow: String(localized: "ui.imageAlignment.overflow.label", bundle: .module)
        case .fullWidth: String(localized: "ui.imageAlignment.fullWidth.label", bundle: .module)
        }
    }

    static func imageAlignmentAnnouncement(_ alignment: SlateImageAlignment) -> String {
        switch alignment {
        case .left: String(localized: "ui.imageAlignment.left.announcement", bundle: .module)
        case .center: String(localized: "ui.imageAlignment.center.announcement", bundle: .module)
        case .right: String(localized: "ui.imageAlignment.right.announcement", bundle: .module)
        case .overflow: String(localized: "ui.imageAlignment.overflow.announcement", bundle: .module)
        case .fullWidth: String(localized: "ui.imageAlignment.fullWidth.announcement", bundle: .module)
        }
    }

    static func imageAlignmentWidthBadge(_ alignment: SlateImageAlignment) -> String {
        switch alignment {
        case .left, .center, .right: String(localized: "ui.imageAlignment.widthBadge.column", bundle: .module)
        case .overflow: String(localized: "ui.imageAlignment.widthBadge.overflow", bundle: .module)
        case .fullWidth: String(localized: "ui.imageAlignment.fullWidth.label", bundle: .module)
        }
    }

    // MARK: - ThemeManager.Appearance

    static func themeAppearanceDisplayName(_ appearance: ThemeManager.Appearance) -> String {
        switch appearance {
        case .system: String(localized: "ui.theme.appearance.system", bundle: .module)
        case .light: String(localized: "ui.theme.appearance.light", bundle: .module)
        case .dark: String(localized: "ui.theme.appearance.dark", bundle: .module)
        }
    }

    // MARK: - ThemeManager.BodyFontChoice

    static func themeFontDisplayName(_ choice: ThemeManager.BodyFontChoice) -> String {
        switch choice {
        case .sans: String(localized: "ui.theme.font.sans", bundle: .module)
        case .serif: String(localized: "ui.theme.font.serif", bundle: .module)
        }
    }

    // MARK: - SlateAccentColor

    static func accentDisplayName(_ accent: SlateAccentColor) -> String {
        switch accent {
        case .blue: String(localized: "ui.accent.blue", bundle: .module)
        case .purple: String(localized: "ui.accent.purple", bundle: .module)
        case .pink: String(localized: "ui.accent.pink", bundle: .module)
        case .red: String(localized: "ui.accent.red", bundle: .module)
        case .orange: String(localized: "ui.accent.orange", bundle: .module)
        case .yellow: String(localized: "ui.accent.yellow", bundle: .module)
        case .green: String(localized: "ui.accent.green", bundle: .module)
        case .graphite: String(localized: "ui.accent.graphite", bundle: .module)
        }
    }
}

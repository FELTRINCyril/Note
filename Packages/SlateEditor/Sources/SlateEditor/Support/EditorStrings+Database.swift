import Foundation
import SlateModel

/// Chaines du bloc `databaseView` (Phase 17, `docs/17_base_de_donnees.md`) -- extrait de
/// `EditorStrings.swift` pour rester sous la limite de longueur de fichier de
/// `CLAUDE.md` §5, meme motif exact que `EditorStrings+Media.swift`. Meme type
/// (`EditorStrings`), aucune nouvelle surface publique qui lui soit propre.
extension EditorStrings {
    /// Libelle du type de bloc `.databaseView`, extrait de `blockTypeLabel(_:)` -- meme
    /// motif que `mediaTypeLabel(_:)`.
    static func databaseTypeLabel(_ type: BlockType) -> String? {
        guard type == .databaseView else { return nil }
        return String(localized: "editor.blockType.databaseView", bundle: .module)
    }

    /// Sous-titre de la commande "/" `.databaseView`, extrait de
    /// `slashCommandSubtitle(_:)` -- meme motif que `mediaSlashCommandSubtitle(_:)`.
    static func databaseSlashCommandSubtitle(_ type: BlockType) -> String? {
        guard type == .databaseView else { return nil }
        return String(localized: "editor.slashCommand.subtitle.databaseView", bundle: .module)
    }

    static var databaseViewMissing: String { String(localized: "editor.databaseView.missing", bundle: .module) }
    static var databaseViewAddRow: String { String(localized: "editor.databaseView.addRow", bundle: .module) }
    static var databaseViewAddField: String { String(localized: "editor.databaseView.addField", bundle: .module) }
    static var databaseViewDeleteRow: String { String(localized: "editor.databaseView.deleteRow", bundle: .module) }
    static var databaseViewCellValue: String { String(localized: "editor.databaseView.cellValue", bundle: .module) }
    static var databaseViewUnsupportedCellType: String {
        String(localized: "editor.databaseView.unsupportedCellType", bundle: .module)
    }
    static var databaseViewFieldNamePlaceholder: String {
        String(localized: "editor.databaseView.fieldNamePlaceholder", bundle: .module)
    }

    /// Libelle du type de champ propose par `InlineDatabaseFieldAdditionView` (texte/
    /// nombre/date/case a cocher/URL uniquement -- voir sa documentation de tete).
    static func databaseFieldTypeLabel(_ type: DatabaseFieldType) -> String {
        switch type {
        case .text: String(localized: "editor.databaseView.fieldType.text", bundle: .module)
        case .number: String(localized: "editor.databaseView.fieldType.number", bundle: .module)
        case .date: String(localized: "editor.databaseView.fieldType.date", bundle: .module)
        case .checkbox: String(localized: "editor.databaseView.fieldType.checkbox", bundle: .module)
        case .url: String(localized: "editor.databaseView.fieldType.url", bundle: .module)
        case .singleSelect, .multiSelect, .createdDate, .modifiedDate, .relation, .rollup:
            type.rawValue
        }
    }
}

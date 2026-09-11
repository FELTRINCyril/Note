import Foundation
import SlateModel

/// Actions ponctuelles sur les blocs speciaux de la Phase 8 (docs/08_blocs_speciaux.md)
/// qui ne meritent pas leur propre fichier d'extension (une methode courte chacune, pas
/// de nouvel etat `@Observable`) : case a cocher d'un `todo`, langage d'un bloc `code`,
/// icone d'un `callout`, indentation d'un item de liste. Le tableau, plus consequent,
/// vit dans son propre fichier (`EditorController+Table.swift`) -- meme motif de
/// separation que `EditorController+Selection.swift`/`+SlashMenu.swift`/`+Formatting.swift` :
/// aucune nouvelle surface publique qui ne soit pas portee par `EditorController`
/// lui-meme.
extension EditorController {
    // MARK: - Case a cocher (`BlockType.todo`)

    /// Bascule/fixe l'etat coche d'un item de liste a cocher (docs/08 : "Case a cocher
    /// fonctionnelle... persistee"). Sans effet si `block` n'est pas un `.todo`, ou si
    /// `isChecked` est deja la valeur courante (evite une ecriture/sauvegarde sans
    /// changement reel).
    public func setChecked(_ isChecked: Bool, in block: Block) {
        guard block.type == .todo, block.attributes.isChecked != isChecked else { return }
        block.attributes.isChecked = isChecked
        persistStructuralChange()
    }

    // MARK: - Langage d'un bloc de code (`BlockType.code`)

    /// Change le langage de coloration syntaxique d'un bloc code (`BlockAttributes.
    /// language`, identifiant `SyntaxLanguage.rawValue` -- voir `SlateServices`). Sans
    /// effet si `block` n'est pas un `.code`, ou si `language` est deja la valeur
    /// courante.
    public func setCodeLanguage(_ language: String, in block: Block) {
        guard block.type == .code, block.attributes.language != language else { return }
        block.attributes.language = language
        persistStructuralChange()
    }

    // MARK: - Icone d'un callout (`BlockType.callout`)

    /// Change l'icone/emoji libre d'un callout (`BlockAttributes.calloutIcon`). Sans
    /// effet si `block` n'est pas un `.callout`, ou si `icon` est deja la valeur
    /// courante. `nil` retombe sur le repli visuel de `SlateUI` (voir
    /// `CalloutBlockContentView`).
    public func setCalloutIcon(_ icon: String?, in block: Block) {
        guard block.type == .callout, block.attributes.calloutIcon != icon else { return }
        block.attributes.calloutIcon = icon
        persistStructuralChange()
    }

    /// Change la variante d'un callout (`BlockAttributes.calloutVariant`, identifiant
    /// `SlateCalloutVariant.rawValue` -- voir `CalloutVariantResolver`). Prend une
    /// `String?` brute plutot que le type `SlateUI` lui-meme : meme convention que
    /// `setCodeLanguage(_:in:)` (`SyntaxLanguage.rawValue`), ce fichier ne depend
    /// d'aucun type de presentation. Sans effet si `block` n'est pas un `.callout`, ou
    /// si `variant` est deja la valeur courante.
    public func setCalloutVariant(_ variant: String?, in block: Block) {
        guard block.type == .callout, block.attributes.calloutVariant != variant else { return }
        block.attributes.calloutVariant = variant
        persistStructuralChange()
    }

    // MARK: - Indentation d'un item de liste (Tab / Maj+Tab, voir `BlockIndentation`)

    /// Tab sur un item de liste : voir `BlockIndentation.indent(_:)`. `false` sans effet
    /// si `block` n'est pas un item de liste ou n'a pas de frere precedent sous lequel
    /// s'imbriquer -- l'appelant AppKit (`RichTextEditingTextView.insertTab(_:)`) doit
    /// alors laisser le comportement natif (insertion d'une tabulation) s'executer.
    @discardableResult
    public func indentBlock(_ block: Block) -> Bool {
        guard BlockIndentation.indent(block) else { return false }
        persistStructuralChange()
        return true
    }

    /// Maj+Tab sur un item de liste : voir `BlockIndentation.outdent(_:)`. Meme regle de
    /// retour que `indentBlock(_:)`.
    @discardableResult
    public func outdentBlock(_ block: Block) -> Bool {
        guard BlockIndentation.outdent(block) else { return false }
        persistStructuralChange()
        return true
    }
}

import Foundation
import SlateModel

/// Cas particulier `image`/`file` de l'execution du menu "/" (Phase 9,
/// docs/09_medias_pieces_jointes.md) -- extrait de `EditorController+SlashMenu.swift`
/// pour rester sous la limite de longueur de fichier de `CLAUDE.md` §5, meme motif de
/// separation que `EditorController+Table.swift`/`+SpecialBlocks.swift`. Un seul type
/// (`EditorController`), aucune nouvelle surface publique qui lui soit propre.
extension EditorController {
    /// Meme motif exact que `executeTableCommand(in:)` (voir sa documentation dans
    /// `EditorController+SlashMenu.swift`) -- ni `image` ni `file` ne portent de
    /// `RichText` propre ni ne peuvent accueillir le caret (aucun `NSTextView`, voir
    /// `BlockRenderRouting`), donc TOUJOURS un nouveau bloc insere en dessous de
    /// `block` (jamais de conversion "en place", `block` reste tel quel), suivi d'un
    /// paragraphe vide qui recoit le focus. Le bloc media lui-meme reste dans son etat
    /// vide/depot (`ImageBlockContentView`/`FileBlockContentView`) jusqu'a ce que
    /// l'utilisateur y depose, y colle ou y choisisse un fichier. Pas `private`
    /// (appelee depuis `EditorController+SlashMenu.swift`, seul autre fichier qui en a
    /// besoin -- meme convention que `applyFocus(_:)`/`persistStructuralChange()`).
    func executeMediaCommand(targetType: BlockType, in block: Block) {
        let mediaBlock = Block(type: targetType)
        BlockOrdering.insert(mediaBlock, after: block)

        let trailingParagraph = Block(type: .paragraph, text: RichText())
        BlockOrdering.insert(trailingParagraph, after: mediaBlock)
        applyFocus(EditorCaretRequest(blockID: trailingParagraph.id, placement: .offset(0)))
    }
}

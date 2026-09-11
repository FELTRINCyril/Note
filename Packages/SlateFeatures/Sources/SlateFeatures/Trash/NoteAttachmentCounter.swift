import SlateModel

/// Compte les pieces jointes d'une note, en descendant recursivement dans
/// `Block.children` (meme parcours que `Note.collectText`, prive) - une piece jointe
/// peut porter sur un bloc imbrique (image dans une colonne, fichier dans un item de
/// liste...), pas seulement sur un bloc racine.
///
/// Utilise par `DeletePermanentlyAlert` (design P3, artboard B : "Cette note et ses 2
/// pieces jointes seront effacees...").
public enum NoteAttachmentCounter {
    public static func count(in note: Note) -> Int {
        count(in: note.blocks ?? [])
    }

    private static func count(in blocks: [Block]) -> Int {
        blocks.reduce(0) { partial, block in
            partial + (block.attachment != nil ? 1 : 0) + count(in: block.children ?? [])
        }
    }
}

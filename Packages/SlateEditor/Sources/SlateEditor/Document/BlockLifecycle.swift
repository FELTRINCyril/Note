import Foundation
import SlateModel

/// Logique PURE (aucune dependance AppKit, aucun `ModelContext`) du cycle de vie des
/// blocs au clavier (docs/05_editeur_blocs.md, sous-etape 5.3). Opere directement sur
/// le graphe `Block`/`Note` deja en memoire -- exactement comme les tests existants de
/// `BlockOrderingTests` (`note.blocks = [...]` sans conteneur SwiftData) -- pour rester
/// entierement testable sans NSTextView. `EditorController` est la SEULE facade
/// appelee par la couche AppKit ; elle delegue tout calcul ici et se contente
/// d'appliquer le resultat (focus, caret, persistance).
///
/// ## Decisions documentees pour les cas ambigus de la spec E4
///
/// - **Entree en debut de bloc non vide.** Insere un bloc vide juste AU-DESSUS, garde
///   le focus sur le bloc courant (dont le contenu ne change pas) -- comportement
///   usuel d'un editeur de blocs (Notion, Notes), explicitement suggere par le doc de
///   tache ("inserer un bloc vide AU-DESSUS et garder le focus sur le bloc courant").
/// - **Entree en fin de bloc : type du nouveau bloc.** Il herite du type du bloc
///   courant UNIQUEMENT pour un item de liste (`bulletedList`/`numberedList`/`todo`) --
///   continuer une liste cree un nouvel item de la MEME liste. Pour tout autre type
///   (paragraphe, titre, citation, code...), le nouveau bloc est un simple paragraphe :
///   creer un titre ou une citation supplementaire "par accident" en appuyant sur
///   Entree serait surprenant, un paragraphe neutre est le repli attendu partout
///   ailleurs (et c'est deja le comportement pour un paragraphe lui-meme).
/// - **Entree sur un item de liste VIDE.** Convertit l'item en paragraphe plutot que de
///   creer un item vide supplementaire -- comportement Notion/Notes explicitement
///   demande par le doc de tache.
/// - **Entree au milieu d'un bloc (split).** Les DEUX moities gardent le type ET les
///   `BlockAttributes` du bloc d'origine : scinder un item de liste coche cree deux
///   items coches, pas un item + un paragraphe.
/// - **Retour arriere en debut de bloc, bloc precedent NON textuel** (`divider`,
///   `image`, `table`...). Rien a fusionner textuellement : le bloc non textuel est
///   retire, le caret reste en debut du bloc courant (inchange par ailleurs) --
///   reproduit le geste "supprimer le separateur au-dessus" plutot que de fusionner du
///   texte dans du vide.
/// - **Retour arriere sur le premier bloc de la note** (aucun bloc avant lui dans
///   l'ordre visuel complet du document, `BlockOrdering.block(before:)`). Aucune
///   operation : le dernier bloc restant d'une note n'est ainsi jamais supprimable par
///   ce geste, la note reste toujours editable.
/// - **Bloc supprime porteur d'enfants** (ex: sous-item d'une liste vide qu'on
///   supprime). Ses enfants sont PROMUS a sa place plutot que supprimes en cascade --
///   voir `BlockOrdering.remove(_:)`. Aucune perte de contenu.
@MainActor
public enum BlockLifecycle {
    // MARK: - Entree

    /// `caretOffset` : position du caret au moment de l'appui, en offset de
    /// CARACTERES (pas UTF-16/octets) dans `block.text`.
    public static func handleEnter(in block: Block, caretOffset: Int) -> EditorCaretRequest {
        let text = block.text ?? RichText()
        let length = text.attributedString.characters.count

        if length == 0 {
            // Bloc entierement vide : convertir plutot que creer un item vide de plus
            // (voir la documentation de tete de fichier).
            if isListType(block.type) {
                block.type = .paragraph
            }
            return EditorCaretRequest(blockID: block.id, placement: .offset(0))
        }

        let clampedOffset = max(0, min(caretOffset, length))

        if clampedOffset == 0 {
            let above = Block(type: continuationType(of: block.type), text: RichText())
            BlockOrdering.insert(above, before: block)
            return EditorCaretRequest(blockID: block.id, placement: .offset(0))
        }

        if clampedOffset == length {
            let below = Block(type: continuationType(of: block.type), text: RichText())
            BlockOrdering.insert(below, after: block)
            return EditorCaretRequest(blockID: below.id, placement: .offset(0))
        }

        let (head, tail) = text.split(atCharacterOffset: clampedOffset)
        block.text = head
        let below = Block(type: block.type, text: tail, attributes: block.attributes)
        BlockOrdering.insert(below, after: block)
        return EditorCaretRequest(blockID: below.id, placement: .offset(0))
    }

    // MARK: - Retour arriere en debut de bloc

    /// A appeler UNIQUEMENT quand le caret est exactement en debut de bloc, sans
    /// selection (l'appelant AppKit garantit cette precondition -- voir
    /// `RichTextEditingTextView.deleteBackward(_:)`). Retourne `nil` si aucune
    /// operation ne doit avoir lieu (premier bloc de la note).
    public static func handleBackspaceAtStart(in block: Block) -> EditorCaretRequest? {
        guard let previous = BlockOrdering.block(before: block) else { return nil }

        guard isTextBearing(previous.type) else {
            BlockOrdering.remove(previous)
            return EditorCaretRequest(blockID: block.id, placement: .offset(0))
        }

        let currentText = block.text ?? RichText()

        if currentText.isEmpty {
            let previousLength = (previous.text ?? RichText()).attributedString.characters.count
            BlockOrdering.remove(block)
            return EditorCaretRequest(blockID: previous.id, placement: .offset(previousLength))
        }

        let previousText = previous.text ?? RichText()
        let joinOffset = previousText.attributedString.characters.count
        var merged = previousText.attributedString
        merged.append(currentText.attributedString)
        previous.text = RichText(attributedString: merged)

        BlockOrdering.remove(block)
        return EditorCaretRequest(blockID: previous.id, placement: .offset(joinOffset))
    }

    // MARK: - Types

    private static func isListType(_ type: BlockType) -> Bool {
        type == .bulletedList || type == .numberedList || type == .todo
    }

    private static func continuationType(of type: BlockType) -> BlockType {
        isListType(type) ? type : .paragraph
    }

    /// Memes types que `Note.textBearingTypes` (`SlateModel`, prive) -- duplique ici
    /// volontairement : ce fichier ne doit pas dependre d'un detail interne de
    /// `SlateModel` hors de son perimetre (voir `CLAUDE.md` §4, sens des dependances),
    /// et cette liste est stable dans le temps (voir la documentation de `BlockType` :
    /// un `rawValue` existant ne se supprime jamais).
    private static func isTextBearing(_ type: BlockType) -> Bool {
        switch type {
        case .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .bulletedList, .numberedList, .todo, .quote, .callout, .code:
            return true
        case .divider, .image, .file, .table, .columnList, .column, .bookmark, .embed, .databaseView, .pageLink:
            return false
        }
    }
}

import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// Le texte riche (attributs inline : gras, italique, surlignage, lien...) doit
/// survivre a une SEQUENCE d'operations structurelles, pas seulement a une operation
/// ISOLEE (revue finale de Phase 5, docs/CLAUDE.md §"Pertes de donnees recurrentes").
/// Chaque suite de tests par operation (`RichTextSplittingTests`, `BlockConversionTests`)
/// verifie deja la preservation pour UNE SEULE operation ; ce fichier enchaine
/// split -> fusion -> conversion -> duplication sur le MEME contenu et verifie que
/// l'attribut pose au tout depart est encore present a la fin.
@MainActor
@Suite("Survie du texte riche a travers une sequence d'operations")
struct RichTextSurvivalAcrossOperationsTests {
    @Test("Gras pose au depart : survit a Entree (split), Backspace (fusion), conversion, duplication")
    func boldSurvivesSplitMergeConvertDuplicate() {
        var text = RichText(plainText: "Bonjour le monde")
        // "Bonjour" (0..<7) en gras.
        text.apply(.bold, to: text.range(charactersOffset: 0..<7))

        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: text, note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        // 1) Entree au milieu ("Bonjour" | " le monde") : split, le gras doit rester
        // entierement sur la moitie de tete.
        controller.handleEnter(in: block, caretOffset: 7)
        let afterSplit = BlockOrdering.topLevelBlocks(of: note)
        #expect(afterSplit.count == 2)
        let head = afterSplit[0]
        let tail = afterSplit[1]
        let headRuns = head.text?.attributedString.runs
        let headHasBold = headRuns?.contains { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(headHasBold == true)
        #expect(head.text?.plainText == "Bonjour")

        // 2) Backspace en tete du second bloc : fusionne, le gras doit toujours
        // couvrir EXACTEMENT "Bonjour" dans le bloc fusionne.
        controller.handleBackspaceAtBlockStart(tail)
        let afterMerge = BlockOrdering.topLevelBlocks(of: note)
        #expect(afterMerge.count == 1)
        let merged = afterMerge[0]
        #expect(merged.text?.plainText == "Bonjour le monde")
        let boldRun = merged.text?.attributedString.runs.first { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(boldRun != nil, "le gras doit survivre a la fusion")
        // Le run en gras doit correspondre exactement a "Bonjour" (pas etendu, pas
        // tronque par la fusion).
        if let boldRun, let text = merged.text {
            let boldSubstring = String(text.attributedString[boldRun.range].characters)
            #expect(boldSubstring == "Bonjour")
        }

        // 3) Conversion en titre : `BlockConversion.convert` ne touche jamais le texte.
        controller.convertBlock(merged, to: .heading2)
        #expect(merged.type == .heading2)
        let mergedRuns = merged.text?.attributedString.runs
        let mergedHasBold = mergedRuns?.contains { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(mergedHasBold == true)
        #expect(merged.text?.plainText == "Bonjour le monde")

        // 4) Duplication : le double doit porter le MEME gras (copie de valeur du
        // `RichText`, voir `BlockOperations.duplicate`).
        controller.duplicateBlock(merged)
        let afterDuplicate = BlockOrdering.topLevelBlocks(of: note)
        #expect(afterDuplicate.count == 2)
        let duplicate = afterDuplicate.first { $0.id != merged.id }
        #expect(duplicate?.text?.plainText == "Bonjour le monde")
        let duplicateRuns = duplicate?.text?.attributedString.runs
        let duplicateHasBold = duplicateRuns?.contains { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(duplicateHasBold == true)
    }

    // MARK: - Unites d'offset a travers la frontiere AppKit -> logique pure
    //
    // Historique du defaut (revue finale de Phase 5, corrige par cette meme revue) :
    // `NSTextView.selectedRange().location` est TOUJOURS en unites UTF-16, alors que
    // `BlockLifecycle.handleEnter(in:caretOffset:)` attend un offset en `Character`.
    // Passer l'un a la place de l'autre SANS CONVERSION divergeait silencieusement des
    // qu'un caractere avant le caret occupait plus d'une unite UTF-16 (emoji hors du
    // plan Unicode de base, la plupart des drapeaux, certains caracteres combines) : le
    // split se produisait au mauvais endroit, sans crash, sans log.
    //
    // Corrige en introduisant `RichTextOffset` (voir sa documentation) : `caretOffset`
    // est desormais un `RichTextOffset`, jamais un `Int` nu, et la SEULE facon de le
    // construire a partir d'un `NSRange.location` UTF-16 passe par
    // `RichTextOffset(utf16Offset:in:)` -- exactement le calcul qu'effectue
    // `RichTextEditingTextView.insertNewline(_:)` sur un vrai `NSTextView`. Les tests
    // ci-dessous reproduisent ce calcul fidelement (sans dependre d'AppKit) pour
    // demontrer que le bug historique ne peut plus se reproduire : NE JAMAIS reintroduire
    // un `Int` nu a cette frontiere, precisement ce qui a cause le defaut.

    @Test("Emoji juste AVANT le caret : le split tombe exactement apres l'emoji, pas apres l'espace suivant")
    func emojiImmediatelyBeforeCaretSplitsAtTheRightBoundary() {
        // "👍" est UN SEUL `Character` Swift (grapheme cluster) mais DEUX unites UTF-16
        // (paire de substituts, U+1F44D hors du plan de base) : 9 `Character`, 10 UTF-16.
        let plainText = "👍 Bonjour"
        let text = RichText(plainText: plainText)
        #expect(text.attributedString.characters.count == 9)
        #expect(plainText.utf16.count == 10, "'👍' occupe 2 unites UTF-16")

        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: text, note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        // Ce qu'un vrai NSTextView rapporterait pour un caret place juste apres "👍" :
        // 2 unites UTF-16 (PAS 1, qui serait l'offset en Character).
        let utf16OffsetRightAfterEmoji = ("👍" as NSString).length
        #expect(utf16OffsetRightAfterEmoji == 2)
        let caretOffset = RichTextOffset(utf16Offset: utf16OffsetRightAfterEmoji, in: plainText)
        let comment: Comment = "1 Character, pas 2 -- la conversion doit corriger le decalage"
        #expect(caretOffset == RichTextOffset(characters: 1), comment)

        controller.handleEnter(in: block, caretOffset: caretOffset)

        let parts = BlockOrdering.topLevelBlocks(of: note)
        #expect(parts.count == 2)
        // Split exactement apres l'emoji : la tete est "👍" SEUL, la queue garde
        // l'espace et "Bonjour" -- si le bug historique etait present, la tete serait
        // "👍 " (emoji + espace) et la queue "Bonjour" (l'espace aurait glisse du mauvais
        // cote, voir la documentation de tete de section).
        #expect(parts[0].text?.plainText == "👍")
        #expect(parts[1].text?.plainText == " Bonjour")
    }

    @Test("Emoji A L'INTERIEUR du bloc (pas en tete) : le split tombe toujours juste apres l'emoji")
    func emojiWithinInteriorTextSplitsAtTheRightBoundary() {
        // "Salut 👍 monde" : l'emoji n'est plus le premier caractere, pour verifier que
        // la conversion reste correcte quand du texte latin simple (1 UTF-16 par
        // Character) precede l'emoji.
        let plainText = "Salut 👍 monde"
        let text = RichText(plainText: plainText)

        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: text, note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        // "Salut " (6 UTF-16, texte latin) + "👍" (2 UTF-16) = 8 UTF-16 juste apres
        // l'emoji, alors que l'offset en Character correspondant est 7 (S,a,l,u,t,' ',👍).
        let utf16OffsetRightAfterEmoji = ("Salut 👍" as NSString).length
        #expect(utf16OffsetRightAfterEmoji == 8)
        let caretOffset = RichTextOffset(utf16Offset: utf16OffsetRightAfterEmoji, in: plainText)
        #expect(caretOffset == RichTextOffset(characters: 7))

        controller.handleEnter(in: block, caretOffset: caretOffset)

        let parts = BlockOrdering.topLevelBlocks(of: note)
        #expect(parts.count == 2)
        #expect(parts[0].text?.plainText == "Salut 👍")
        #expect(parts[1].text?.plainText == " monde")
    }

    @Test("Fusion (Backspace) dans un texte contenant un emoji : le caret retombe a la jointure exacte")
    func mergeWithEmojiInPreviousBlockPlacesCaretAtExactJoint() {
        // Le bloc PRECEDENT (celui dans lequel on fusionne) contient un emoji : le
        // caret post-fusion doit atterrir juste APRES "👍" cote AppKit (UTF-16), pas
        // decale par la meme confusion d'unites.
        let previousPlainText = "👍 Bonjour"
        let note = Note(title: "Test")
        let previous = Block(order: 0, type: .paragraph, text: RichText(plainText: previousPlainText), note: note)
        let current = Block(order: 1, type: .paragraph, text: RichText(plainText: " le monde"), note: note)
        note.blocks = [previous, current]
        let controller = EditorController(note: note)

        controller.handleBackspaceAtBlockStart(current)

        let remaining = BlockOrdering.topLevelBlocks(of: note)
        #expect(remaining.count == 1)
        let merged = remaining[0]
        #expect(merged.text?.plainText == "👍 Bonjour le monde")

        guard case let .offset(caretOffset)? = controller.consumePendingCaretRequest(for: merged.id)?.placement else {
            Issue.record("aucune requete de caret .offset apres la fusion")
            return
        }
        // La jointure est a 9 Character (longueur de "👍 Bonjour") -- verifie a la fois
        // le compte de caracteres ET sa reconversion UTF-16 (10 : 2 pour l'emoji + 1
        // espace + 7 lettres de "Bonjour"), pour couvrir la frontiere retour vers AppKit.
        #expect(caretOffset == RichTextOffset(characters: 9))
        let mergedPlainText = merged.text?.plainText ?? ""
        #expect(caretOffset.utf16Offset(in: mergedPlainText) == 10)
        // Verifie le CONTENU de part et d'autre de la jointure, pas seulement sa
        // position numerique : couper "👍 Bonjour le monde" a 9 Character doit
        // retomber exactement entre "Bonjour" et " le monde".
        let characters = Array(mergedPlainText)
        let head = String(characters.prefix(caretOffset.characters))
        let tail = String(characters.suffix(from: caretOffset.characters))
        #expect(head == "👍 Bonjour")
        #expect(tail == " le monde")
    }

    @Test("Grapheme multi-scalaire (drapeau) : la conversion UTF-16 <-> Characters reste correcte")
    func multiScalarGraphemeFlagConvertsAndSplitsCorrectly() {
        // "🇫🇷" est UN SEUL `Character` Swift (les deux indicateurs regionaux se
        // combinent en un seul grapheme) mais QUATRE unites UTF-16 (deux symboles hors
        // du plan Unicode de base, chacun une paire de substituts).
        let plainText = "🇫🇷 Bonjour"
        let text = RichText(plainText: plainText)
        #expect(text.attributedString.characters.count == 9) // 🇫🇷, espace, B,o,n,j,o,u,r
        #expect(("🇫🇷" as NSString).length == 4, "le drapeau occupe 4 unites UTF-16 pour 1 seul Character")

        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: text, note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        let utf16OffsetRightAfterFlag = ("🇫🇷" as NSString).length
        let caretOffset = RichTextOffset(utf16Offset: utf16OffsetRightAfterFlag, in: plainText)
        #expect(caretOffset == RichTextOffset(characters: 1))

        controller.handleEnter(in: block, caretOffset: caretOffset)

        let parts = BlockOrdering.topLevelBlocks(of: note)
        #expect(parts.count == 2)
        #expect(parts[0].text?.plainText == "🇫🇷")
        #expect(parts[1].text?.plainText == " Bonjour")
    }
}

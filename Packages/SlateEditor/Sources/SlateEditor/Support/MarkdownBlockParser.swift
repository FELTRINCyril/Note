import Foundation
import SlateModel

/// Logique PURE (aucune dependance AppKit/`Block`/`ModelContext`) de decoupage d'un
/// texte markdown MULTI-LIGNES en une liste de blocs (docs/15_markdown_natif.md,
/// "Coller du markdown -> conversion optionnelle en blocs"). Meme famille que
/// `MarkdownShortcutEngine`, dont ce parseur reutilise directement les motifs (aucune
/// liste de marqueurs dupliquee) : la seule addition reellement MULTI-LIGNES est le
/// bloc de code delimite par ``` ``` ``` sur plusieurs lignes -- tous les autres motifs
/// restent, comme a la frappe, des motifs A UNE SEULE LIGNE (un bloc de ce modele
/// d'edition ne porte jamais de saut de ligne interne, sauf precisement ce cas).
///
/// ## Modele : une ligne non vide = un bloc, une ligne vide = un separateur de blocs
/// Ce projet n'a pas de notion de "paragraphe markdown multi-lignes fusionne en un seul
/// bloc" : chaque ligne non vide devient son propre bloc (motif detecte ou simple
/// paragraphe), exactement comme si l'utilisateur avait tape cette ligne puis Entree.
/// Une ligne vide ne produit AUCUN bloc, elle sert seulement a separer visuellement deux
/// groupes de lignes dans le texte source.
public enum MarkdownBlockParser {
    /// Un bloc issu du parsing, pas encore attache a une `Note`/un `ModelContext` --
    /// `EditorController+MarkdownPaste.swift` le materialise en `Block` reel.
    public struct ParsedBlock: Equatable, Sendable {
        public let type: BlockType
        public let text: RichText
        /// Significatif uniquement pour `.todo` (motifs `[] `/`[x] `) ; `false` pour
        /// tout autre type, jamais lu dans ce cas (meme convention que
        /// `BlockAttributes.isChecked`, deja non-optionnelle par choix du projet).
        public let isChecked: Bool
    }

    /// `true` si `text` contient au moins un motif markdown reconnu (bloc OU inline) --
    /// l'appelant (collage) s'en sert pour decider de convertir ou d'inserer le texte
    /// brut tel quel, SANS construire la liste de blocs correspondante (evite le travail
    /// de `parse(_:)` quand il sera de toute facon jete).
    public static func containsMarkdownSyntax(_ text: String) -> Bool {
        var index = 0
        let lines = text.components(separatedBy: "\n")
        while index < lines.count {
            let line = lines[index]
            if isFenceLine(line) { return true }
            if line == "---" { return true }
            if MarkdownShortcutEngine.blockLinePrefixTrigger(line: line) != nil { return true }
            if MarkdownShortcutEngine.firstInlineTrigger(in: line) != nil { return true }
            index += 1
        }
        return false
    }

    /// Decoupe `text` en blocs, dans l'ordre. Vide pour un texte vide ou entierement
    /// compose de lignes blanches.
    public static func parse(_ text: String) -> [ParsedBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [ParsedBlock] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            for line in paragraphLines {
                blocks.append(parseSingleLine(line))
            }
            paragraphLines = []
        }

        var index = 0
        while index < lines.count {
            let line = lines[index]
            if isFenceLine(line) {
                flushParagraph()
                index = appendCodeBlock(startingAt: index, in: lines, into: &blocks)
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph()
            } else {
                paragraphLines.append(line)
            }
            index += 1
        }
        flushParagraph()
        return blocks
    }

    // MARK: - Bloc de code (le seul motif reellement multi-lignes, voir la doc de tete)

    private static func isFenceLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("```")
    }

    /// `lines[startIndex]` est deja verifiee comme ligne de cloture ouvrante (voir
    /// `isFenceLine`). Accumule les lignes suivantes TELLES QUELLES (jamais interpretees
    /// comme du markdown -- meme regle que la frappe a l'interieur d'un bloc `.code`,
    /// voir `MarkdownShortcutEngine`) jusqu'a la ligne de cloture fermante, ou jusqu'a la
    /// fin du texte si la cloture n'est jamais refermee (le contenu accumule est quand
    /// meme conserve, plutot que silencieusement perdu). Retourne l'index de la
    /// PROCHAINE ligne a traiter par l'appelant.
    private static func appendCodeBlock(
        startingAt startIndex: Int, in lines: [String], into blocks: inout [ParsedBlock]
    ) -> Int {
        var index = startIndex + 1
        var codeLines: [String] = []
        while index < lines.count, !isFenceLine(lines[index]) {
            codeLines.append(lines[index])
            index += 1
        }
        blocks.append(
            ParsedBlock(type: .code, text: RichText(plainText: codeLines.joined(separator: "\n")), isChecked: false)
        )
        // Si `index` pointe sur la ligne de fermeture (cas nominal), elle est consommee
        // ici ; si elle a atteint la fin du texte (cloture jamais refermee), ce +1 reste
        // sans effet sur la boucle appelante (`index < lines.count` echouera).
        return index + 1
    }

    // MARK: - Toute autre ligne : motif de bloc a une seule ligne, ou paragraphe

    private static func parseSingleLine(_ line: String) -> ParsedBlock {
        if line == "---" {
            return ParsedBlock(type: .divider, text: RichText(), isChecked: false)
        }
        if let trigger = MarkdownShortcutEngine.blockLinePrefixTrigger(line: line) {
            let content = String(line.dropFirst(trigger.markerLength))
            let isChecked: Bool
            if case let .forced(value) = trigger.checkedOverride { isChecked = value } else { isChecked = false }
            let text = applyingInlineMarkdown(to: RichText(plainText: content))
            return ParsedBlock(type: trigger.targetType, text: text, isChecked: isChecked)
        }
        let text = applyingInlineMarkdown(to: RichText(plainText: line))
        return ParsedBlock(type: .paragraph, text: text, isChecked: false)
    }

    /// Consomme TOUTES les marques inline d'une ligne (potentiellement plusieurs, ex.
    /// `**gras** et *italique*`), une a la fois de gauche a droite -- voir
    /// `MarkdownShortcutEngine.firstInlineTrigger(in:)`.
    private static func applyingInlineMarkdown(to text: RichText) -> RichText {
        var result = text
        while let trigger = MarkdownShortcutEngine.firstInlineTrigger(in: result.plainText) {
            result = MarkdownShortcutEngine.consuming(trigger, in: result)
        }
        return result
    }
}

import SlateModel
import Testing

@testable import SlateEditor

/// `MarkdownShortcutEngine` (docs/15_markdown_natif.md) : logique PURE, aucun
/// `NSTextView`/`Block` -- un test par motif, comme demande explicitement par la spec,
/// plus les faux positifs documentes ("jamais au milieu d'une ligne", "jamais dans un
/// bloc non vide").
@Suite("MarkdownShortcutEngine")
struct MarkdownShortcutEngineTests {
    // MARK: - Declencheurs de bloc a l'espace : les 6 niveaux de titre

    @Test("H1 a H6 : chaque niveau de dieses suivi d'une espace declenche le bon niveau")
    func headingLevelsTrigger() {
        let expectations: [(String, BlockType)] = [
            ("# ", .heading1), ("## ", .heading2), ("### ", .heading3),
            ("#### ", .heading4), ("##### ", .heading5), ("###### ", .heading6)
        ]
        for (marker, expectedType) in expectations {
            let trigger = MarkdownShortcutEngine.blockSpaceTrigger(text: marker, caret: marker.count)
            #expect(trigger?.targetType == expectedType, "motif \(marker)")
            #expect(trigger?.markerLength == marker.count, "motif \(marker)")
            #expect(trigger?.checkedOverride == .unspecified, "motif \(marker)")
        }
    }

    @Test("Un septieme diese n'est plus un titre valide")
    func sevenHashesIsNotAHeading() {
        #expect(MarkdownShortcutEngine.blockSpaceTrigger(text: "####### ", caret: 8) == nil)
    }

    // MARK: - Declencheurs de bloc a l'espace : les 3 listes, tache cochee/non cochee, citation

    @Test("Tiret ou asterisque suivi d'une espace declenche une liste a puces")
    func bulletedListTriggers() {
        for marker in ["- ", "* "] {
            let trigger = MarkdownShortcutEngine.blockSpaceTrigger(text: marker, caret: marker.count)
            #expect(trigger?.targetType == .bulletedList, "motif \(marker)")
            #expect(trigger?.markerLength == 2, "motif \(marker)")
        }
    }

    @Test("\"1. \" declenche une liste numerotee")
    func numberedListTriggers() {
        let trigger = MarkdownShortcutEngine.blockSpaceTrigger(text: "1. ", caret: 3)
        #expect(trigger?.targetType == .numberedList)
        #expect(trigger?.markerLength == 3)
    }

    @Test("\"[] \" declenche une tache NON cochee")
    func uncheckedTodoTriggers() {
        let trigger = MarkdownShortcutEngine.blockSpaceTrigger(text: "[] ", caret: 3)
        #expect(trigger?.targetType == .todo)
        #expect(trigger?.checkedOverride == .forced(false))
        #expect(trigger?.markerLength == 3)
    }

    @Test("\"[x] \" declenche une tache COCHEE")
    func checkedTodoTriggers() {
        let trigger = MarkdownShortcutEngine.blockSpaceTrigger(text: "[x] ", caret: 4)
        #expect(trigger?.targetType == .todo)
        #expect(trigger?.checkedOverride == .forced(true))
        #expect(trigger?.markerLength == 4)
    }

    @Test("\"> \" declenche une citation")
    func quoteTriggers() {
        let trigger = MarkdownShortcutEngine.blockSpaceTrigger(text: "> ", caret: 2)
        #expect(trigger?.targetType == .quote)
        #expect(trigger?.markerLength == 2)
    }

    @Test("Le texte suivant le marqueur est preserve comme contenu, hors du marqueur")
    func trailingContentIsNotPartOfTheMarker() {
        let trigger = MarkdownShortcutEngine.blockSpaceTrigger(text: "# Bonjour", caret: 2)
        #expect(trigger?.targetType == .heading1)
        #expect(trigger?.markerLength == 2)
    }

    // MARK: - Declencheurs de bloc a l'espace : faux positifs

    @Test("Diese sans espace ne declenche rien")
    func hashWithoutSpaceDoesNotTrigger() {
        #expect(MarkdownShortcutEngine.blockSpaceTrigger(text: "#sans espace", caret: 1) == nil)
    }

    @Test("Un tiret suivi d'une espace au MILIEU d'une ligne ne declenche rien")
    func dashInTheMiddleOfALineDoesNotTrigger() {
        // Le caret n'est PAS immediatement apres le marqueur depuis le debut du texte :
        // "et - ou" ne peut jamais matcher "text[0..<caret] == '- '".
        #expect(MarkdownShortcutEngine.blockSpaceTrigger(text: "et - ou", caret: 5) == nil)
    }

    @Test("Un marqueur precede d'un autre caractere ne declenche rien")
    func markerPrecededByOtherCharacterDoesNotTrigger() {
        #expect(MarkdownShortcutEngine.blockSpaceTrigger(text: "x- ", caret: 3) == nil)
    }

    // MARK: - Declencheurs de bloc a l'Entree : bloc de code, separateur

    @Test("Trois backticks, contenu EXACT du bloc, declenchent un bloc de code")
    func codeBlockTriggersOnReturn() {
        #expect(MarkdownShortcutEngine.blockReturnTrigger(text: "```") == .codeBlock)
    }

    @Test("Trois tirets, contenu EXACT du bloc, declenchent un separateur")
    func dividerTriggersOnReturn() {
        #expect(MarkdownShortcutEngine.blockReturnTrigger(text: "---") == .divider)
    }

    @Test("\"---\" dans un bloc qui contient AUTRE CHOSE ne declenche rien (conflit documente)")
    func dividerDoesNotTriggerInNonEmptyBlock() {
        #expect(MarkdownShortcutEngine.blockReturnTrigger(text: "Un texte --- avec des tirets") == nil)
        #expect(MarkdownShortcutEngine.blockReturnTrigger(text: "----") == nil)
        #expect(MarkdownShortcutEngine.blockReturnTrigger(text: "---suite") == nil)
    }

    // MARK: - Formatage inline : les 5 marques

    @Test("**gras** declenche le gras au second asterisque fermant")
    func boldTriggers() {
        let text = "**gras**"
        let trigger = MarkdownShortcutEngine.inlineTrigger(justTyped: "*", text: text, caret: text.count)
        #expect(trigger?.kind == .bold)
        #expect(trigger?.contentRange == 2..<6)
        #expect(trigger?.openDelimiterLength == 2)
        #expect(trigger?.closeDelimiterLength == 2)
    }

    @Test("*italique* declenche l'italique au second asterisque fermant")
    func italicTriggers() {
        let text = "*italique*"
        let trigger = MarkdownShortcutEngine.inlineTrigger(justTyped: "*", text: text, caret: text.count)
        #expect(trigger?.kind == .italic)
        #expect(trigger?.contentRange == 1..<9)
        #expect(trigger?.openDelimiterLength == 1)
        #expect(trigger?.closeDelimiterLength == 1)
    }

    @Test("`code` declenche le code inline au backtick fermant")
    func inlineCodeTriggers() {
        let text = "`code`"
        let trigger = MarkdownShortcutEngine.inlineTrigger(justTyped: "`", text: text, caret: text.count)
        #expect(trigger?.kind == .inlineCode)
        #expect(trigger?.contentRange == 1..<5)
    }

    @Test("~~barre~~ declenche le barre au second tilde fermant")
    func strikethroughTriggers() {
        let text = "~~barre~~"
        let trigger = MarkdownShortcutEngine.inlineTrigger(justTyped: "~", text: text, caret: text.count)
        #expect(trigger?.kind == .strikethrough)
        #expect(trigger?.contentRange == 2..<7)
    }

    @Test("==surlignage== declenche le surlignage au second egal fermant")
    func highlightTriggers() {
        let text = "==surlignage=="
        let trigger = MarkdownShortcutEngine.inlineTrigger(justTyped: "=", text: text, caret: text.count)
        #expect(trigger?.kind == .highlight)
        #expect(trigger?.contentRange == 2..<12)
    }

    // MARK: - Formatage inline : ordre gras/italique, faux positifs

    @Test("**gras** n'est PAS confondu avec de l'italique (le gras est essaye en premier)")
    func boldTakesPriorityOverItalic() {
        let text = "**gras**"
        let trigger = MarkdownShortcutEngine.inlineTrigger(justTyped: "*", text: text, caret: text.count)
        #expect(trigger?.kind == .bold)
    }

    @Test("Delimiteurs immediatement adjacents (contenu vide) ne declenchent rien")
    func emptyContentDoesNotTrigger() {
        #expect(MarkdownShortcutEngine.inlineTrigger(justTyped: "*", text: "****", caret: 4) == nil)
        #expect(MarkdownShortcutEngine.inlineTrigger(justTyped: "`", text: "``", caret: 2) == nil)
    }

    @Test("Un delimiteur fermant sans OUVRANT correspondant ne declenche rien")
    func unmatchedClosingDelimiterDoesNotTrigger() {
        let text = "italique*"
        #expect(MarkdownShortcutEngine.inlineTrigger(justTyped: "*", text: text, caret: text.count) == nil)
    }
}

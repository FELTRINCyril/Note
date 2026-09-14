import Foundation
import SlateModel

/// Logique PURE (aucune dependance AppKit, aucun `Block`/`ModelContext`) de detection
/// des raccourcis markdown a la frappe (docs/15_markdown_natif.md). Meme motif que
/// `BlockOrdering`/`BlockIndentation`/`TableNavigation`/`FormatBarPositioning`/
/// `BlockDropResolution` : opere uniquement sur des `String`/`Int` deja extraits par la
/// couche AppKit, entierement testable sans `NSTextView` ni fenetre.
///
/// ## Trois familles de declencheurs
/// - `blockSpaceTrigger(text:caret:)` : motifs de bloc qui se declenchent des la frappe
///   de l'espace qui les termine (`# `, `- `, `1. `, `[] `, `[x] `, `> `).
/// - `blockReturnTrigger(text:)` : motifs de bloc SANS espace, qui ne se declenchent
///   qu'a la frappe d'Entree, et seulement si le bloc ne contient RIEN d'autre que le
///   motif (docs/15, conflit "`---` contre le separateur" : jamais au milieu d'un bloc
///   par ailleurs non vide).
/// - `inlineTrigger(justTyped:text:caret:)` : formatage inline, qui se declenche a la
///   frappe du DELIMITEUR FERMANT (`**`, `*`, `` ` ``, `~~`, `==`).
///
/// Chaque appelant (`EditorController+MarkdownShortcuts.swift`) est responsable de
/// restreindre l'appel a un bloc de type `.paragraph` (declencheurs de bloc) ou
/// different de `.code` (declencheur inline) -- cette couche pure ne connait pas
/// `BlockType` du bloc COURANT, seulement le texte qu'il porte.
public enum MarkdownShortcutEngine {
    // MARK: - Declencheurs de bloc actives par une espace

    /// Motif de bloc detecte a la frappe d'une espace terminale.
    /// `discouraged_optional_boolean` (SwiftLint) interdit un `Bool?` : cet enum porte
    /// exactement la meme information ("ne force rien" / "force cette valeur") sans
    /// optionnel booleen.
    public enum CheckedOverride: Equatable, Sendable {
        /// `BlockConversion.convert` conserve l'etat coche existant (voir sa
        /// documentation) -- tous les motifs autres que `[] `/`[x] `.
        case unspecified
        /// Force explicitement l'etat coche d'un `.todo` (motifs `[x] `/`[] `).
        case forced(Bool)
    }

    public struct BlockSpaceTrigger: Equatable, Sendable {
        public let targetType: BlockType
        public let checkedOverride: CheckedOverride
        /// Nombre de CARACTERES du marqueur entier (espace terminale incluse), a
        /// retirer en tete du texte du bloc pour "consommer" la syntaxe.
        public let markerLength: Int
    }

    /// Detecte un declencheur de bloc a la frappe d'une espace : `text` est le contenu
    /// ACTUEL du bloc (immediatement apres l'espace tapee), `caret` la position du
    /// caret (en CARACTERES, immediatement apres cette espace). Le marqueur doit
    /// occuper EXACTEMENT `text[0..<caret]` -- jamais un marqueur precede d'un autre
    /// caractere (docs/15, "en debut de ligne uniquement") : ce qui suit `caret`, s'il y
    /// en a, devient le contenu du bloc converti, inchange par cette fonction.
    public static func blockSpaceTrigger(text: String, caret: Int) -> BlockSpaceTrigger? {
        guard caret > 0, caret <= text.count else { return nil }
        let prefix = String(text.prefix(caret))

        if let level = headingLevel(ofSpacePrefix: prefix) {
            return BlockSpaceTrigger(
                targetType: headingType(level: level), checkedOverride: .unspecified, markerLength: caret
            )
        }
        switch prefix {
        case "- ", "* ":
            return BlockSpaceTrigger(targetType: .bulletedList, checkedOverride: .unspecified, markerLength: caret)
        case "1. ":
            return BlockSpaceTrigger(targetType: .numberedList, checkedOverride: .unspecified, markerLength: caret)
        case "[] ":
            return BlockSpaceTrigger(targetType: .todo, checkedOverride: .forced(false), markerLength: caret)
        case "[x] ":
            return BlockSpaceTrigger(targetType: .todo, checkedOverride: .forced(true), markerLength: caret)
        case "> ":
            return BlockSpaceTrigger(targetType: .quote, checkedOverride: .unspecified, markerLength: caret)
        default:
            return nil
        }
    }

    /// `1` a `6` si `prefix` est EXACTEMENT `N` dieses suivis d'une espace (`# ` a
    /// `###### `), `nil` sinon -- au-dela de 6, `####### ` n'est plus un titre valide
    /// (docs/15 : "H1...H6" seulement).
    private static func headingLevel(ofSpacePrefix prefix: String) -> Int? {
        guard prefix.count >= 2, prefix.count <= 7, prefix.hasSuffix(" ") else { return nil }
        let hashes = prefix.dropLast()
        guard hashes.allSatisfy({ $0 == "#" }) else { return nil }
        return hashes.count
    }

    private static func headingType(level: Int) -> BlockType {
        switch level {
        case 1: .heading1
        case 2: .heading2
        case 3: .heading3
        case 4: .heading4
        case 5: .heading5
        default: .heading6
        }
    }

    // MARK: - Declencheurs de bloc actives par Entree (sans espace)

    /// Motif de bloc SANS espace, dont l'unique declencheur est l'Entree.
    public enum BlockReturnTrigger: Equatable, Sendable {
        case codeBlock
        case divider
    }

    /// Detecte un declencheur de bloc a la frappe d'Entree : ne se declenche QUE si
    /// `text` (le contenu ENTIER du bloc, rien d'autre) est exactement l'un des motifs
    /// -- docs/15, conflit "`---` contre le separateur" : jamais sur un bloc qui
    /// contient autre chose que le motif, jamais au milieu d'un bloc non vide.
    public static func blockReturnTrigger(text: String) -> BlockReturnTrigger? {
        switch text {
        case "```": .codeBlock
        case "---": .divider
        default: nil
        }
    }

    // MARK: - Formatage inline active par le delimiteur fermant

    public enum InlineTriggerKind: Equatable, Sendable {
        case bold
        case italic
        case inlineCode
        case strikethrough
        case highlight
    }

    /// Motif inline detecte : `contentRange` designe le contenu (delimiteurs exclus),
    /// en offsets de CARACTERES dans `text` -- a l'appelant de le traduire en indices
    /// `AttributedString` (voir `RichText.range(charactersOffset:)`).
    public struct InlineTrigger: Equatable, Sendable {
        public let kind: InlineTriggerKind
        public let contentRange: Range<Int>
        public let openDelimiterLength: Int
        public let closeDelimiterLength: Int
    }

    /// Detecte un formatage inline a la frappe de `justTyped`, le DERNIER caractere
    /// insere dans `text` (deja present dans `text`, `caret` juste apres lui -- meme
    /// convention que `EditorController.updateSlashMenuState`/`detectOpening`, qui
    /// suppose deja que le caret suit immediatement le caractere qui vient d'etre
    /// tape). Cherche, en remontant depuis `caret`, le delimiteur OUVRANT le plus
    /// proche : plage de contenu VIDE (delimiteurs immediatement adjacents, ex `****`)
    /// ou aucun delimiteur ouvrant trouve -> `nil`, aucune conversion.
    ///
    /// ## Ordre gras/italique (docs/15, conflit "`*` contre `**`")
    /// `*` est essaye d'abord comme fermeture de GRAS (`**...**`, delimiteur de 2
    /// caracteres) puis, seulement si aucune paire `**` correspondante n'est trouvee,
    /// comme fermeture d'ITALIQUE (`*...*`, delimiteur de 1 caractere) -- l'ordre
    /// inverse ferait qu'un `**gras**` complet ne se convertirait jamais en gras (la
    /// premiere `*` de la paire fermante serait deja consommee par une detection
    /// italique prematuree).
    public static func inlineTrigger(justTyped: Character, text: String, caret: Int) -> InlineTrigger? {
        guard caret >= 2, caret <= text.count else { return nil }
        let characters = Array(text)
        switch justTyped {
        case "*":
            return delimiterTrigger(characters: characters, caret: caret, delimiter: "*", length: 2, kind: .bold)
                ?? delimiterTrigger(characters: characters, caret: caret, delimiter: "*", length: 1, kind: .italic)
        case "`":
            return delimiterTrigger(
                characters: characters, caret: caret, delimiter: "`", length: 1, kind: .inlineCode
            )
        case "~":
            return delimiterTrigger(
                characters: characters, caret: caret, delimiter: "~", length: 2, kind: .strikethrough
            )
        case "=":
            return delimiterTrigger(characters: characters, caret: caret, delimiter: "=", length: 2, kind: .highlight)
        default:
            return nil
        }
    }

    /// Cherche une paire de delimiteurs de `length` caracteres identiques (`delimiter`
    /// repete) se refermant exactement a `caret` : la fermeture occupe
    /// `[caret - length, caret)`, l'ouverture recherchee la plus proche occupe
    /// `[i, i + length)` pour le plus grand `i` tel que `i + length <= caret - length`.
    /// Aucune correspondance, ou contenu vide entre les deux paires -> `nil`.
    private static func delimiterTrigger(
        characters: [Character], caret: Int, delimiter: Character, length: Int, kind: InlineTriggerKind
    ) -> InlineTrigger? {
        guard caret - length >= 0 else { return nil }
        let closeStart = caret - length
        guard isDelimiterRun(characters, from: closeStart, length: length, delimiter: delimiter) else { return nil }

        var openStart = closeStart - length
        while openStart >= 0 {
            if isDelimiterRun(characters, from: openStart, length: length, delimiter: delimiter) {
                let contentRange = (openStart + length)..<closeStart
                guard !contentRange.isEmpty else { return nil }
                return InlineTrigger(
                    kind: kind, contentRange: contentRange, openDelimiterLength: length, closeDelimiterLength: length
                )
            }
            openStart -= 1
        }
        return nil
    }

    private static func isDelimiterRun(
        _ characters: [Character], from start: Int, length: Int, delimiter: Character
    ) -> Bool {
        guard start >= 0, start + length <= characters.count else { return false }
        return characters[start..<(start + length)].allSatisfy { $0 == delimiter }
    }

    // MARK: - Reutilisation par le collage (docs/15, `MarkdownBlockParser`)
    //
    // Les deux fonctions ci-dessous adaptent les motifs de bloc/inline ci-dessus a un
    // contexte SANS caret (une LIGNE entiere issue d'un texte colle, plutot qu'une
    // frappe ponctuelle) -- sans dupliquer la liste des marqueurs elle-meme, qui reste
    // entierement portee par `blockSpaceTrigger`/`inlineTrigger` ci-dessus.

    /// Variante de `blockSpaceTrigger(text:caret:)` SANS position de caret connue a
    /// l'avance : essaie chaque longueur de marqueur possible (les plus longs marqueurs
    /// de ce fichier, `[x] `, ne depassent jamais 4 caracteres) et retourne le premier
    /// qui correspond exactement au DEBUT de `line`. Utilisee pour un texte colle, ou
    /// chaque ligne est deja entierement connue (par opposition a la frappe, ou seule la
    /// position du caret l'est).
    public static func blockLinePrefixTrigger(line: String) -> BlockSpaceTrigger? {
        let maxCaret = min(7, line.count)
        guard maxCaret > 0 else { return nil }
        for caret in 1...maxCaret {
            if let trigger = blockSpaceTrigger(text: line, caret: caret) {
                return trigger
            }
        }
        return nil
    }

    /// Premier declencheur inline trouve en balayant `text` de GAUCHE A DROITE --
    /// symmetrique de `inlineTrigger(justTyped:text:caret:)`, qui suppose lui un caret
    /// DEJA place juste apres le delimiteur fermant (le cas de la frappe). Un texte
    /// colle n'a pas de caret : cette fonction trouve la PREMIERE paire complete, pour
    /// que l'appelant (`MarkdownBlockParser`) puisse la consommer puis re-balayer le
    /// reste tant qu'il en reste (plusieurs marques inline par ligne).
    ///
    /// ## Piege ecarte : tester au MILIEU d'une sequence de delimiteurs identiques
    /// N'essaie `inlineTrigger` qu'a la fin de chaque SEQUENCE MAXIMALE de delimiteurs
    /// identiques consecutifs (ex: les DEUX `*` de `**`), jamais a chaque caractere
    /// individuel de cette sequence. Sans cette regle, `**gras**` etait detecte a tort :
    /// tester juste apres le PREMIER `*` de la paire OUVRANTE `**` (avant meme d'avoir vu
    /// "gras") retombe sur la branche ITALIQUE de `inlineTrigger` (`**` echoue comme
    /// fermeture GRAS a cette position, faute de contenu avant elle), qui elle trouve une
    /// fausse correspondance en remontant jusqu'au `*` isole le plus proche -- retourne
    /// AVANT d'atteindre la vraie paire fermante `**` deux caracteres plus loin. Ne
    /// tester qu'a la fin de la sequence (caret juste apres les DEUX `*`) reproduit
    /// exactement la condition reelle d'une frappe ("le delimiteur complet vient d'etre
    /// tape"), la seule que `inlineTrigger` sait interpreter correctement.
    public static func firstInlineTrigger(in text: String) -> InlineTrigger? {
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            guard character == "*" || character == "`" || character == "~" || character == "=" else {
                index += 1
                continue
            }
            var runEnd = index
            while runEnd + 1 < characters.count, characters[runEnd + 1] == character {
                runEnd += 1
            }
            if let trigger = inlineTrigger(justTyped: character, text: text, caret: runEnd + 1) {
                return trigger
            }
            index = runEnd + 1
        }
        return nil
    }

    /// Applique `trigger` a `text` (marque posee sur le contenu, delimiteurs retires) --
    /// logique PURE partagee par la frappe (`EditorController+MarkdownShortcuts.swift`)
    /// et le collage (`MarkdownBlockParser`), pour qu'il n'existe qu'un seul endroit qui
    /// sache comment "consommer" un `InlineTrigger`.
    public static func consuming(_ trigger: InlineTrigger, in text: RichText) -> RichText {
        var result = text
        result.apply(inlineMark(for: trigger.kind), to: result.range(charactersOffset: trigger.contentRange))
        result = result.removingCharacters(in: RichTextRange(
            lowerBound: RichTextOffset(characters: trigger.contentRange.upperBound),
            upperBound: RichTextOffset(characters: trigger.contentRange.upperBound + trigger.closeDelimiterLength)
        ))
        result = result.removingCharacters(in: RichTextRange(
            lowerBound: RichTextOffset(characters: trigger.contentRange.lowerBound - trigger.openDelimiterLength),
            upperBound: RichTextOffset(characters: trigger.contentRange.lowerBound)
        ))
        return result
    }

    /// `InlineMark` (`SlateModel`) correspondante. "jaune" par defaut pour le
    /// surlignage : meme identifiant que la premiere pastille de la palette
    /// (`EditorInlineFormattingColors.SlateHighlightToken.yellow`, `SlateUI`) -- le
    /// markdown ne laisse pas le choix de la couleur, ce defaut est celui qu'un
    /// utilisateur choisirait le plus probablement lui-meme en premier.
    public static func inlineMark(for kind: InlineTriggerKind) -> InlineMark {
        switch kind {
        case .bold: .bold
        case .italic: .italic
        case .inlineCode: .inlineCode
        case .strikethrough: .strikethrough
        case .highlight: .highlight(SlateHighlightColor("yellow"))
        }
    }
}

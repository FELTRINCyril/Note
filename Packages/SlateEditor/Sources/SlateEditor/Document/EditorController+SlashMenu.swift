import Foundation
import SlateModel

/// Etat du menu de commandes "/" ouvert pour UN bloc precis (docs/06_slash_commandes.md,
/// sous-etape 6.3). Type pur (aucun AppKit) : `anchorOffset` fige la position du `/`
/// lui-meme dans le texte du bloc au moment de l'ouverture, `query` est recalculee a
/// chaque frappe par `EditorController.updateSlashMenuState(for:plainText:caretOffset:)`.
public struct SlashMenuState: Equatable, Sendable {
    let blockID: UUID
    /// Offset de CARACTERES (`RichTextOffset`, jamais un `Int` nu -- voir sa
    /// documentation) du `/` lui-meme dans `Block.text.plainText`. Le `/` reste dans le
    /// texte pendant toute la duree d'ouverture du menu (spec 6.4 : "le / RESTE dans le
    /// texte tant que le menu est ouvert") -- ce n'est qu'a l'execution
    /// (`EditorController.executeSlashCommand(_:in:)`) qu'il est retire, avec le reste
    /// de la requete.
    let anchorOffset: RichTextOffset
    /// Texte tape entre le `/` et le caret, recalcule a chaque frappe. Peut etre vide
    /// (menu juste ouvert, ou requete effacee sans fermer le menu).
    var query: String
    /// Identifiant de la commande actuellement mise en avant (`SlashCommand.id`),
    /// pilote au clavier (fleches) et par le survol souris. `nil` seulement quand
    /// aucune commande ne correspond a `query` (etat vide -- voir `SlashMenuView`).
    var selectedCommandID: String?
}

/// Logique du menu "/" (docs/06_slash_commandes.md, sous-etapes 6.3 "controleur", 6.4
/// "detection et priorite clavier", 6.6 "execution") : detection d'ouverture, mise a
/// jour de la requete a chaque frappe, regles de fermeture, navigation clavier avec
/// bouclage, et execution (conversion en place ou insertion d'un nouveau bloc). Separe
/// de `EditorController.swift` pour rester sous la limite de longueur de fichier de
/// `CLAUDE.md` §5 -- meme motif exact que `EditorController+Selection.swift`, aucune
/// nouvelle surface publique QUI LUI SERAIT PROPRE (un seul type `EditorController`,
/// comme documente par ce fichier voisin).
///
/// ## Testable HORS AppKit, meme regle que le reste de `EditorController`
/// Aucune methode ici ne prend un `NSTextView`/`NSRange` : `updateSlashMenuState(for:
/// plainText:caretOffset:)` recoit un `String` et un `RichTextOffset` DEJA extraits par
/// la couche AppKit (`RichTextBlockView.Coordinator`, dans
/// `textViewDidChangeSelection(_:)` -- fonctionne aussi bien sur une frappe que sur un
/// simple deplacement de caret, les deux faisant bouger la selection). Les tests
/// construisent directement des `Note`/`Block` en memoire et appellent ces methodes,
/// exactement comme le reste de `EditorControllerTests`.
///
/// ## Pourquoi la detection d'OUVERTURE et de FERMETURE partagent la meme fonction
/// `updateSlashMenuState(for:plainText:caretOffset:)` est le SEUL point d'entree pour
/// toute frappe/deplacement de caret dans un bloc, qu'un menu soit deja ouvert ou pas --
/// pas deux methodes distinctes "essayer d'ouvrir" / "mettre a jour" que l'appelant
/// devrait choisir entre elles selon un etat qu'il ne devrait pas avoir a connaitre. Elle
/// route elle-meme vers `detectOpening`/`recomputedQuery` selon que `slashMenuState`
/// vise deja ce bloc.
///
/// ## Regle de fermeture "espace tapee" : conditionnee au resultat, pas absolue
/// `SlashCommandRegistry` porte de nombreux alias ET plusieurs TITRES contenant une
/// espace ("Titre 1".."Titre 6", "liste a puces", "case a cocher", "bloc de code"...) :
/// fermer sur TOUT espace, sans condition, aurait rendu cette surface de recherche
/// entiere injoignable ("/titre 1" se serait ferme a l'espace, laissant "/titre 1" en
/// texte brut). La regle retenue distingue deux cas :
/// 1. **Requete ENTIEREMENT blanche** (un ou plusieurs caracteres, tous des espaces --
///    typiquement une SEULE espace tapee juste apres le `/`) : ferme TOUJOURS, sans
///    consulter le filtrage. Necessaire car `SlashCommandFilter` fait remonter des
///    correspondances par ALIAS meme pour une requete d'une seule espace (sous-sequence
///    triviale d'un caractere dans n'importe quel alias qui en contient un, ex.
///    "heading 1") : sans cette regle degeneree separee, "et / ou"/"23 / 45" ne
///    fermeraient jamais a la premiere espace tapee apres le `/`.
/// 2. **Requete non blanche contenant une espace ailleurs** ("titre 1", "liste a
///    puces"...) : ferme UNIQUEMENT si elle ne correspond plus a AUCUNE commande --
///    c'est ce qui empeche une phrase en prose plus longue de garder le menu ouvert
///    indefiniment, sans fermer les alias/titres multi-mots reels du registre.
///
/// Consequence assumee : l'etat vide de `SlashMenuView` (`emptyStateMessage`) n'est
/// desormais atteignable QUE pour une requete SANS espace -- une requete contenant une
/// espace et zero resultat ferme le menu avant meme d'atteindre cet etat, alors qu'une
/// requete sans espace et zero resultat (ex: "/zzzzzz") le garde ouvert normalement.
/// Voir `recomputedQuery(for:plainText:caretOffset:)` pour l'implementation exacte.
extension EditorController {
    // MARK: - Detection d'ouverture / mise a jour de la requete (sous-etape 6.4)

    /// A appeler par la couche AppKit a CHAQUE frappe ET a chaque deplacement de caret
    /// dans `block` (voir la documentation de tete de fichier) -- `plainText` et
    /// `caretOffset` reflettent l'etat COURANT du bloc, apres la frappe/le deplacement.
    public func updateSlashMenuState(for block: Block, plainText: String, caretOffset: RichTextOffset) {
        if let state = slashMenuState, state.blockID == block.id {
            guard let newQuery = Self.recomputedQuery(for: state, plainText: plainText, caretOffset: caretOffset) else {
                slashMenuState = nil
                return
            }
            var updated = state
            updated.query = newQuery
            updated.selectedCommandID = Self.clampedSelection(state.selectedCommandID, forQuery: newQuery)
            slashMenuState = updated
            return
        }

        // Un menu ouvert pour un AUTRE bloc ne devrait normalement jamais atteindre ce
        // point (`noteBlockDidBeginEditing(_:)`/`noteBlockDidEndEditing(_:)` le ferment
        // deja au changement de focus) -- garde defensive plutot qu'une precondition,
        // par coherence avec le reste du fichier (voir sa documentation de tete).
        guard slashMenuState == nil else { return }

        guard let opened = Self.detectOpening(plainText: plainText, caretOffset: caretOffset, blockID: block.id) else {
            return
        }
        var state = opened
        state.selectedCommandID = Self.clampedSelection(nil, forQuery: state.query)
        slashMenuState = state
    }

    /// Ferme le menu "/" inconditionnellement, quel que soit le bloc vise -- utilise par
    /// la couche AppKit pour Echap (`handleSlashMenuEscape(in:)`) et par ce fichier a la
    /// validation d'une commande. Public pour rester coherent avec le reste de la
    /// surface de `EditorController` (chaque geste utilisateur a sa methode dediee),
    /// meme si aucun appelant externe n'en a besoin aujourd'hui au-dela de ce module.
    public func closeSlashMenu() {
        slashMenuState = nil
    }

    /// Le `/` vient-il d'etre tape en debut de bloc, ou precede d'un espace (sous-etape
    /// 6.4 : "jamais au milieu d'un mot, sinon une URL ou 'et/ou' ouvrirait le menu") ?
    /// `caretOffset` doit etre IMMEDIATEMENT apres le `/` (caret == positionDuSlash + 1)
    /// pour que l'ouverture soit detectee -- un `/` tape puis le caret deplace ailleurs
    /// avant que cette fonction ne soit appelee ne doit pas ouvrir le menu a retardement.
    private static func detectOpening(
        plainText: String, caretOffset: RichTextOffset, blockID: UUID
    ) -> SlashMenuState? {
        let characters = Array(plainText)
        let caret = max(0, min(caretOffset.characters, characters.count))
        guard caret >= 1, characters[caret - 1] == "/" else { return nil }

        let slashIndex = caret - 1
        guard slashIndex == 0 || characters[slashIndex - 1].isWhitespace else { return nil }

        return SlashMenuState(
            blockID: blockID,
            anchorOffset: RichTextOffset(characters: slashIndex),
            query: "",
            selectedCommandID: nil
        )
    }

    /// Recalcule la requete d'un menu DEJA ouvert pour ce bloc, ou `nil` si l'une des
    /// regles de fermeture de la sous-etape 6.4 s'applique :
    /// - le `/` a l'`anchorOffset` a disparu (supprime, ou le texte est devenu plus
    ///   court que l'ancre elle-meme) ;
    /// - le caret est revenu AU `/` ou avant lui (sorti de la plage de requete "par la
    ///   gauche") ;
    /// - le caret est projete au-dela de la fin du texte (defensif, ne devrait jamais
    ///   arriver avec un `RichTextOffset` deja borne par l'appelant AppKit) ;
    /// - la requete est ENTIEREMENT blanche (une ou plusieurs espaces, aucun autre
    ///   caractere) -- ferme TOUJOURS, voir la documentation de tete de fichier,
    ///   "Regle de fermeture 'espace tapee'", point 1 ;
    /// - la requete N'EST PAS entierement blanche mais contient une espace ET ne
    ///   correspond plus a AUCUNE commande -- voir la meme documentation, point 2. Une
    ///   requete SANS AUCUNE espace et sans resultat, elle, ne ferme PAS le menu (etat
    ///   vide, voir `SlashMenuView.emptyStateMessage`).
    private static func recomputedQuery(
        for state: SlashMenuState, plainText: String, caretOffset: RichTextOffset
    ) -> String? {
        let characters = Array(plainText)
        let anchor = state.anchorOffset.characters
        guard anchor < characters.count, characters[anchor] == "/" else { return nil }

        let caret = caretOffset.characters
        guard caret > anchor, caret <= characters.count else { return nil }

        let queryCharacters = characters[(anchor + 1)..<caret]
        let query = String(queryCharacters)

        let isEntirelyWhitespace = !queryCharacters.isEmpty && queryCharacters.allSatisfy(\.isWhitespace)
        guard !isEntirelyWhitespace else { return nil }

        guard !queryCharacters.contains(where: { $0.isWhitespace }) || !Self.matches(forQuery: query).isEmpty else {
            return nil
        }
        return query
    }

    // MARK: - Navigation clavier (sous-etape 6.4)

    /// Fleche haut/bas alors que le menu est ouvert : deplace `selectedCommandID` d'un
    /// pas dans la liste FILTREE courante, EN BOUCLANT en bout de liste (choix
    /// deliberement documente : un fleche bas sur la derniere commande revient a la
    /// premiere, symmetriquement pour fleche haut sur la premiere -- coherent avec la
    /// plupart des palettes de commandes, et evite qu'une pression prolongee sur une
    /// meme fleche "coince" silencieusement sur un bord sans retour visuel). Retourne
    /// `true` INCONDITIONNELLEMENT si un menu est ouvert pour ce bloc (meme si la liste
    /// filtree est vide -- voir la doc de tete de fichier, "testable hors AppKit") :
    /// tant que le menu est ouvert, la fleche ne doit JAMAIS retomber sur la navigation
    /// de bloc a bloc, y compris dans l'etat vide ou l'utilisateur peut encore corriger
    /// sa frappe.
    ///
    /// `block` n'est PAS decoratif : comme les quatre autres points d'entree du menu
    /// (`handleSlashMenuReturn`, `handleSlashMenuEscape`, `confirmSlashMenuCommand`,
    /// `hoverSlashMenuItem`), cette methode verifie que le menu ouvert est bien celui de
    /// CE bloc avant d'agir. L'invariant `slashMenuState.blockID == focusedBlockID` est
    /// aujourd'hui tenu par ailleurs (`noteBlockDidBeginEditing`/`noteBlockDidEndEditing`
    /// ferment defensivement le menu a tout changement de focus), mais s'appuyer dessus
    /// ICI ferait dependre la correction d'une garantie ETRANGERE a cette methode : un
    /// futur chemin de focus qui contournerait ces deux hooks laisserait une fleche tapee
    /// dans un bloc B piloter silencieusement le menu ouvert sur un bloc A. Chaque point
    /// d'entree verifie donc son propre bloc, sans exception -- une regle uniforme est
    /// plus solide qu'une exception justifiee par l'etat actuel du reste du fichier.
    @discardableResult
    public func moveSlashMenuSelection(_ direction: BlockSelectionDirection, in block: Block) -> Bool {
        guard var state = slashMenuState, state.blockID == block.id else { return false }
        let ids = Self.matches(forQuery: state.query).map(\.command.id)
        guard !ids.isEmpty else { return true }

        let currentIndex = state.selectedCommandID.flatMap { ids.firstIndex(of: $0) }
        let nextIndex: Int
        switch direction {
        case .up:
            nextIndex = currentIndex.map { $0 == 0 ? ids.count - 1 : $0 - 1 } ?? ids.count - 1
        case .down:
            nextIndex = currentIndex.map { $0 == ids.count - 1 ? 0 : $0 + 1 } ?? 0
        }
        state.selectedCommandID = ids[nextIndex]
        slashMenuState = state
        return true
    }

    /// Survol souris (`SlashMenuView.onHover`) : deplace `selectedCommandID` SANS
    /// executer la commande -- voir la documentation de tete de `SlashMenuView`, "le
    /// piege central" (une seule source de verite pour la ligne mise en avant). Sans
    /// effet si aucun menu n'est ouvert, ou si `commandID` ne correspond a aucune
    /// commande de la liste filtree courante (garde defensive contre un `id` perime,
    /// ex: la liste a change entre l'evenement souris et son traitement).
    public func hoverSlashMenuItem(_ commandID: String) {
        guard var state = slashMenuState else { return }
        guard Self.matches(forQuery: state.query).contains(where: { $0.command.id == commandID }) else { return }
        state.selectedCommandID = commandID
        slashMenuState = state
    }

    // MARK: - Entree / Echap (priorite clavier, sous-etape 6.4)

    /// Entree alors que le menu est ouvert pour `block` : valide la commande mise en
    /// avant. `false` si aucun menu n'est ouvert pour `block` (l'appelant AppKit doit
    /// alors laisser `handleEnter(in:caretOffset:)` gerer l'Entree normalement -- voir
    /// `RichTextEditingTextView.insertNewline(_:)`). `true` sinon, MEME si aucune
    /// commande n'est mise en avant (etat vide) : l'Entree est alors simplement
    /// consommee sans effet, jamais laissee scinder le bloc par-dessus un menu ouvert.
    @discardableResult
    public func handleSlashMenuReturn(in block: Block) -> Bool {
        guard let state = slashMenuState, state.blockID == block.id else { return false }
        guard let selectedID = state.selectedCommandID,
              let match = Self.matches(forQuery: state.query).first(where: { $0.command.id == selectedID }) else {
            return true
        }
        executeSlashCommand(match.command, in: block, state: state)
        return true
    }

    /// Echap alors que le menu est ouvert pour `block` : ferme le menu SEUL, sans
    /// selectionner le bloc entier -- DIFFERENT de `handleEscape(in:)` (sortie
    /// d'edition classique). `false` si aucun menu n'est ouvert pour `block` (l'appelant
    /// AppKit doit alors laisser `richTextViewShouldHandleCancelEditing()` s'executer
    /// normalement).
    @discardableResult
    public func handleSlashMenuEscape(in block: Block) -> Bool {
        guard let state = slashMenuState, state.blockID == block.id else { return false }
        slashMenuState = nil
        return true
    }

    // MARK: - Clic souris (sous-etape 6.6)

    /// Clic sur une ligne du menu (`SlashMenuView.onSelect`) : execute TOUJOURS la
    /// commande cliquee, independamment de `selectedCommandID` (un clic direct sur une
    /// ligne different de celle actuellement mise en avant au clavier doit executer la
    /// ligne cliquee, pas celle du clavier -- comportement standard d'une liste
    /// cliquable). Sans effet si aucun menu n'est ouvert pour `block`, ou si `commandID`
    /// ne correspond a aucune commande de la liste filtree courante (garde defensive,
    /// meme raison que `hoverSlashMenuItem(_:)`).
    public func confirmSlashMenuCommand(_ commandID: String, in block: Block) {
        guard let state = slashMenuState, state.blockID == block.id else { return }
        guard let match = Self.matches(forQuery: state.query).first(where: { $0.command.id == commandID }) else { return }
        executeSlashCommand(match.command, in: block, state: state)
    }

    // MARK: - Filtrage (expose pour la vue overlay, docs/06, sous-etape 6.5)

    /// Commandes filtrees pour la requete du menu OUVERT pour `block`, ou vide si aucun
    /// menu n'est ouvert pour ce bloc precis -- l'overlay (sous-etape 6.5, hors
    /// perimetre de ce fichier) n'a ainsi jamais a reimplementer la garde "quel bloc ce
    /// menu vise-t-il vraiment".
    public func slashMenuMatches(for block: Block) -> [SlashCommandMatch] {
        guard let state = slashMenuState, state.blockID == block.id else { return [] }
        return Self.matches(forQuery: state.query)
    }

    private static func matches(forQuery query: String) -> [SlashCommandMatch] {
        SlashCommandFilter.match(query: query, in: SlashCommandRegistry.allCommands)
    }

    /// Selection par defaut/conservee apres un changement de requete : garde
    /// `currentID` s'il correspond encore a une commande de la liste filtree pour
    /// `query`, retombe sinon sur la PREMIERE commande de cette liste (`nil` si la
    /// liste est vide -- etat vide, voir `SlashMenuView.emptyStateMessage`). Cette regle
    /// de conservation evite qu'ajouter/retirer un caractere de la requete fasse
    /// "sauter" la mise en avant loin de la ou l'utilisateur regardait, tant que son
    /// choix reste pertinent.
    private static func clampedSelection(_ currentID: String?, forQuery query: String) -> String? {
        let matches = Self.matches(forQuery: query)
        if let currentID, matches.contains(where: { $0.command.id == currentID }) {
            return currentID
        }
        return matches.first?.command.id
    }

    // MARK: - Execution (sous-etape 6.6)

    /// Execute `command` : retire `/` + la requete du texte du bloc (JAMAIS en
    /// reconstruisant `RichText` depuis une `String`, voir `RichText.
    /// removingCharacters(in:)`), puis convertit `block` en place s'il devient vide,
    /// sinon insere un nouveau bloc du type demande en dessous -- voir la documentation
    /// de tete de `EditorController+SlashMenu.swift` et le cas particulier `divider`
    /// traite par `executeDividerCommand(in:leftoverIsEmpty:)`.
    ///
    /// ## Ecart delibere avec `convertBlock(_:to:)`/`duplicateBlock(_:)`
    /// Ces deux actions du menu de bloc laissent le bloc concerne SELECTIONNE (pas
    /// focalise en edition) apres coup -- voir leur documentation. Ici, le bloc
    /// resultant reste EN EDITION, caret place (`applyFocus(_:)`) : l'utilisateur est en
    /// train de TAPER quand il valide une commande "/", l'interrompre pour le forcer a
    /// recliquer avant de continuer serait absurde. Les deux comportements sont donc
    /// volontairement differents, chacun adapte au geste qui le declenche.
    private func executeSlashCommand(_ command: SlashCommand, in block: Block, state: SlashMenuState) {
        let currentText = block.text ?? RichText()
        let removalRange = RichTextRange(
            lowerBound: state.anchorOffset,
            upperBound: RichTextOffset(characters: state.anchorOffset.characters + 1 + state.query.count)
        )
        let trimmedText = currentText.removingCharacters(in: removalRange)
        block.text = trimmedText
        slashMenuState = nil

        if command.targetType == .divider {
            executeDividerCommand(in: block, leftoverIsEmpty: trimmedText.isEmpty)
        } else if command.targetType == .table {
            executeTableCommand(in: block)
        } else if trimmedText.isEmpty {
            BlockConversion.convert(block, to: command.targetType)
            applyFocus(EditorCaretRequest(blockID: block.id, placement: .offset(0)))
        } else {
            let newBlock = Block(type: command.targetType, text: RichText())
            BlockOrdering.insert(newBlock, after: block)
            applyFocus(EditorCaretRequest(blockID: newBlock.id, placement: .offset(0)))
        }
        persistStructuralChange()
    }

    /// Cas particulier `divider` (voir la documentation de tete de fichier) : `.divider`
    /// n'appartient PAS a `BlockConversion.convertibleTypes` (aucun `RichText` a
    /// transporter) et ne peut PAS accueillir le caret (aucun `NSTextView` -- voir
    /// `BlockRenderRouting`). Le separateur prend donc la place voulue par
    /// `leftoverIsEmpty` (conversion en place de `block` s'il est vide, sinon un
    /// nouveau bloc separateur insere en dessous), puis un paragraphe VIDE est TOUJOURS
    /// insere juste apres lui et recoit le focus -- c'est ce paragraphe, jamais le
    /// separateur, que `applyFocus(_:)` cible.
    private func executeDividerCommand(in block: Block, leftoverIsEmpty: Bool) {
        let dividerBlock: Block
        if leftoverIsEmpty {
            block.attributes = BlockConversion.convertedAttributes(from: block.attributes, to: .divider)
            block.type = .divider
            dividerBlock = block
        } else {
            let newDivider = Block(type: .divider)
            BlockOrdering.insert(newDivider, after: block)
            dividerBlock = newDivider
        }

        let trailingParagraph = Block(type: .paragraph, text: RichText())
        BlockOrdering.insert(trailingParagraph, after: dividerBlock)
        applyFocus(EditorCaretRequest(blockID: trailingParagraph.id, placement: .offset(0)))
    }

    /// Cas particulier `table` (voir la documentation de tete de fichier) : comme
    /// `divider`, `.table` n'appartient PAS a `BlockConversion.convertibleTypes` (pas de
    /// `RichText` propre a transporter, voir sa documentation) et ne peut PAS accueillir
    /// le caret. Un tableau 3x3 par defaut (`Block.makeTable`, `SlateModel`) est TOUJOURS
    /// insere en dessous de `block` -- jamais en conversion "en place", `block` reste tel
    /// quel (vide ou non, la ou `divider` distingue les deux cas : un tableau n'a jamais
    /// eu de raison de "remplacer" un bloc texte existant, contrairement a un
    /// separateur). Un paragraphe VIDE est ensuite insere apres le tableau et recoit le
    /// focus -- meme motif que `executeDividerCommand`, un tableau n'a pas de `NSTextView`
    /// propre a focaliser (voir `TableBlockContentView`, edition par `TextField` par
    /// cellule).
    ///
    /// Dimensions par defaut choisies pour rester utile immediatement sans imposer de
    /// choix supplementaire a l'utilisateur au moment de l'insertion -- l'ajout/le
    /// retrait de lignes/colonnes ensuite (`EditorController+Table.swift`) couvre le
    /// reste du besoin "n x m" de la spec (docs/08_blocs_speciaux.md).
    private func executeTableCommand(in block: Block) {
        let table = Block.makeTable(rows: 3, columns: 3)
        BlockOrdering.insert(table, after: block)

        let trailingParagraph = Block(type: .paragraph, text: RichText())
        BlockOrdering.insert(trailingParagraph, after: table)
        applyFocus(EditorCaretRequest(blockID: trailingParagraph.id, placement: .offset(0)))
    }
}

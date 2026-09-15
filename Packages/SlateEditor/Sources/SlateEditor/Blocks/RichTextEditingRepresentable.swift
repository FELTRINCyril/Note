import AppKit
import os
import SlateModel
import SlateServices
import SlateUI
import SwiftData
import SwiftUI

/// Partie `NSViewRepresentable` proprement dite, separee de `RichTextBlockView` (et,
/// depuis la Phase 7, de son propre FICHIER -- extrait de `RichTextBlockView.swift`
/// pour rester sous la limite de longueur de fichier de `CLAUDE.md` §5) pour que
/// celle-ci reste une simple `View` (lisant son environnement dans `body`, pas dans un
/// type conforme a `NSViewRepresentable` ou l'acces a `context.environment` suit des
/// regles differentes). Pas `private` : `internal`, necessaire depuis `RichTextBlockView.body`.
struct RichTextEditingRepresentable: NSViewRepresentable {
    let block: Block
    let editorController: EditorController
    let modelContext: ModelContext
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(block: block, editorController: editorController, modelContext: modelContext)
    }

    func makeNSView(context: Context) -> RichTextEditingTextView {
        let textView = RichTextEditingTextView.makeTextKit2Instance()
        textView.delegate = context.coordinator
        textView.blockLifecycleDelegate = context.coordinator
        // Typographie du VRAI type de bloc AVANT le contenu initial (Phase 7, H1-H6) :
        // `makeTextKit2Instance()` applique deja une typographie de repli generique
        // (corps de texte, type inconnu a ce stade) via `configureAppearance()` --
        // sans ce second appel ICI, un titre nouvellement monte afficherait son texte
        // avec la police du corps jusqu'a la prochaine modification (`syncModelIfNeeded`
        // ne repousse rien tant que `block.text` n'a pas change depuis l'exterieur).
        textView.applyTypography(for: block.type, isChecked: block.attributes.isChecked)
        context.coordinator.applyInitialContent(to: textView)
        textView.freezesCaretForReduceMotion = reduceMotion
        return textView
    }

    func updateNSView(_ nsView: RichTextEditingTextView, context: Context) {
        context.coordinator.updateModelContext(modelContext)
        nsView.freezesCaretForReduceMotion = reduceMotion
        nsView.applyTypography(for: block.type, isChecked: block.attributes.isChecked)
        context.coordinator.syncModelIfNeeded(into: nsView)
        // Cycle de vie des blocs (sous-etape 5.3) : si l'`EditorController` a une
        // requete de caret en attente pour CE bloc (nouveau bloc cree par Entree,
        // fusion, navigation haut/bas...), c'est ICI qu'elle est appliquee -- ce
        // `NSViewRepresentable` est garanti d'etre `updateNSView`-appele juste apres sa
        // creation par SwiftUI, donc meme un bloc qui vient d'apparaitre dans le
        // `ForEach` recoit bien sa requete au tour de rendu ou elle a ete emise.
        if let request = editorController.consumePendingCaretRequest(for: block.id) {
            nsView.applyCaretPlacement(request.placement)
        } else {
            // Perf (`LazyVStack`, voir `NoteDocumentView`) : ce bloc peut etre un
            // `NSTextView` RECREE apres avoir ete demonte (`dismantleNSView`) pendant
            // qu'il defilait hors-ecran alors qu'il etait le bloc EN EDITION -- voir
            // `Coordinator.restoreFocusAfterRemountIfNeeded`.
            context.coordinator.restoreFocusAfterRemountIfNeeded(
                to: nsView, focusedBlockID: editorController.focusedBlockID
            )
        }
    }

    static func dismantleNSView(_ nsView: RichTextEditingTextView, coordinator: Coordinator) {
        // Voir la documentation de `RichTextBlockView` : c'est ICI que le changement de
        // note et la fermeture de la vue garantissent qu'aucune frappe en attente n'est
        // perdue.
        coordinator.flushPendingSave()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: RichTextEditingTextView, context: Context) -> CGSize? {
        nsView.intrinsicSize(forProposedWidth: proposal.width)
    }

    /// Pont entre le `NSTextView` et `SlateModel` : seul endroit ou `Block.text` est lu
    /// et ecrit, seul endroit ou `BlockSaveDebouncer`/`BlockTextCommit` sont invoques.
    /// `NSObject` + `NSTextViewDelegate` (contrainte AppKit), mais isole au `MainActor`
    /// comme tout le reste de ce fichier -- toutes les methodes de `NSTextViewDelegate`
    /// utilisees ici sont deja appelees sur le fil principal par AppKit.
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, RichTextBlockLifecycleDelegate {
        // Pas `private` (contrairement a la 5.2/7) : `RichTextEditingRepresentable+Rendering.swift`,
        // extension de ce meme type dans un fichier VOISIN (limite de longueur de
        // fichier de `CLAUDE.md` §5, Phase 8), a besoin d'y acceder. Reste `internal` --
        // ce type n'est de toute facon jamais expose hors de ce module.
        let block: Block
        let editorController: EditorController
        var modelContext: ModelContext
        // Pas `private` (meme raison que `block`/`editorController` ci-dessus) :
        // `tryApplyMarkdownAutoformat` (`+Rendering.swift`, Phase 15) y planifie aussi.
        let debouncer = BlockSaveDebouncer()

        /// Dernier contenu connu comme etant IDENTIQUE entre le modele et la vue.
        /// Sert a distinguer "le modele a change depuis l'exterieur" (il faut repousser
        /// le nouveau contenu dans le NSTextView) de "le modele a change parce qu'on
        /// vient d'y ecrire depuis cette meme frappe" (il ne faut RIEN repousser, ca
        /// couperait la composition et deplacerait le caret) -- voir
        /// `syncModelIfNeeded`.
        private var lastSyncedText: RichText?

        /// Dernier `BlockAttributes.isChecked` connu comme deja reflete dans le contenu
        /// affiche (Phase 8) : `syncModelIfNeeded` compare `block.text` ET cette valeur,
        /// car une bascule de case a cocher (`ChecklistItemView`, hors `NSTextView`) ne
        /// touche jamais `block.text` -- sans ce suivi separe, le texte DEJA affiche ne
        /// se barrerait/estomperait qu'a la prochaine frappe, jamais immediatement au
        /// clic sur la case. Ignore pour tout bloc autre qu'un `.todo` (toujours `nil`
        /// dans ce cas, jamais compare). Non-optionnel (`discouraged_optional_boolean`,
        /// `.swiftlint.yml`) : `false` par defaut n'introduit aucune ambiguite, ce champ
        /// est de toute facon reecrit explicitement des `applyInitialContent(to:)`,
        /// avant toute comparaison reelle.
        private var lastSyncedIsChecked = false

        /// Vrai pendant qu'on ecrit programmatiquement dans le `NSTextStorage` (mise a
        /// jour venue du modele, pas de l'utilisateur). Garde-fou defensif contre un
        /// double traitement dans `textDidChange` -- `NSTextStorage.setAttributedString`
        /// ne declenche normalement pas la notification `NSText.didChangeNotification`
        /// (elle est postee par `NSTextView.didChangeText()`, jamais appele ici), mais ce
        /// drapeau documente explicitement l'intention plutot que de compter
        /// silencieusement sur ce detail d'implementation AppKit.
        var isApplyingModelToView = false

        /// `true` une fois qu'une premiere tentative de restauration du focus a ete
        /// faite pour l'instance ACTUELLE de ce `Coordinator` (une par montage de
        /// `NSView`, voir `makeCoordinator()` -- un nouveau montage cree un nouveau
        /// `Coordinator`). Empeche `restoreFocusAfterRemountIfNeeded` de ressaisir le
        /// focus AppKit a CHAQUE `updateNSView` ulterieur : sans ce garde-fou, un
        /// `NSTextView` deja focalise normalement (frappe en cours) reprendrait
        /// premier repondant de force a chaque re-rendu ou `window.firstResponder`
        /// n'est momentanement PAS ce `NSTextView` pour une raison sans rapport (menu de
        /// bloc ouvert en `.popover`, changement de fenetre cle...) -- exactement le
        /// genre de vol de focus intempestif que la tache interdit explicitement.
        private var hasAttemptedFocusRestorationAfterRemount = false

        init(block: Block, editorController: EditorController, modelContext: ModelContext) {
            self.block = block
            self.editorController = editorController
            self.modelContext = modelContext
        }

        func updateModelContext(_ modelContext: ModelContext) {
            self.modelContext = modelContext
        }

        /// Seede le `NSTextView` avec le contenu actuel du bloc, a la creation de la vue.
        func applyInitialContent(to textView: RichTextEditingTextView) {
            let text = block.text ?? RichText()
            apply(text, to: textView)
            lastSyncedText = text
            lastSyncedIsChecked = block.attributes.isChecked
        }

        /// Repousse le contenu du modele dans la vue SEULEMENT s'il a change depuis
        /// l'exterieur (voir la documentation de `lastSyncedText`), OU si l'etat coche
        /// d'un `.todo` a change depuis la derniere synchronisation (voir la
        /// documentation de `lastSyncedIsChecked`, Phase 8). Appele a chaque
        /// `updateNSView`, donc a chaque re-rendu SwiftUI de ce bloc.
        func syncModelIfNeeded(into textView: RichTextEditingTextView) {
            let currentModelText = block.text ?? RichText()
            let currentIsChecked = block.attributes.isChecked
            let checkedStateChanged = block.type == .todo && currentIsChecked != lastSyncedIsChecked
            guard currentModelText != lastSyncedText || checkedStateChanged else { return }
            apply(currentModelText, to: textView)
            lastSyncedText = currentModelText
            lastSyncedIsChecked = currentIsChecked
        }

        /// Execute immediatement toute sauvegarde en attente. Voir la documentation de
        /// `RichTextBlockView` pour les trois moments ou c'est appele.
        func flushPendingSave() {
            debouncer.flush()
        }

        /// Reprend le focus AppKit (premier repondant) sur `textView` SI ce bloc est
        /// toujours designe comme le bloc EN EDITION par l'`EditorController`, mais que
        /// ce `NSTextView` precis (necessairement RECREE par `makeNSView` -- voir
        /// `hasAttemptedFocusRestorationAfterRemount`) ne l'est pas encore.
        ///
        /// ## Pourquoi cette situation existe (Perf, `LazyVStack`)
        /// Le focus AppKit ("premier repondant") et le focus logique
        /// (`EditorController.focusedBlockID`) sont deux etats SEPARES (voir la
        /// documentation de `RichTextEditingTextView.applyCaretPlacement(_:)`). Avec le
        /// `LazyVStack`, un bloc EN EDITION qui defile hors de la zone materialisee est
        /// DEMONTE (`dismantleNSView`, qui sauvegarde mais ne touche PAS
        /// `focusedBlockID`) : le focus AppKit part avec le `NSTextView` detruit. S'il
        /// revient a l'ecran, `makeNSView` construit une instance TOTALEMENT NOUVELLE,
        /// qui n'est premier repondant de rien par defaut -- sans cette methode, la
        /// frappe suivante n'irait nulle part alors que le bloc parait toujours
        /// focalise. Le caret est replace en FIN de contenu (`.end`), sa position
        /// exacte avant demontage n'ayant pas survecu.
        func restoreFocusAfterRemountIfNeeded(to textView: RichTextEditingTextView, focusedBlockID: UUID?) {
            defer { hasAttemptedFocusRestorationAfterRemount = true }
            guard !hasAttemptedFocusRestorationAfterRemount, focusedBlockID == block.id else { return }
            guard textView.window?.firstResponder !== textView else { return }
            textView.applyCaretPlacement(.end)
        }

        // MARK: - NSTextViewDelegate

        func textDidBeginEditing(_ notification: Notification) {
            editorController.noteBlockDidBeginEditing(block.id)
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingModelToView, let textView = notification.object as? NSTextView else { return }

            // Pont NSAttributedString -> AttributedString AVEC le scope explicite
            // `AttributeScopes.SlateAttributes` (surlignage, code inline, souligne --
            // voir `SlateInlineAttributes`). L'initialiseur SANS `including:` ne
            // connait que le scope Foundation natif : il aurait silencieusement
            // PERDU ces trois attributs custom a chaque frappe, quelles que soient
            // leurs conformances ObjC (mesure et corrige en parallele dans
            // `SlateModel`, voir son historique). Throwing : geree explicitement,
            // AUCUN `try?` -- ecraserait `block.text` par une version amputee sans
            // que rien ne le signale, exactement le bug qu'on elimine ici.
            let storage = textView.textStorage ?? NSTextStorage()
            let bridged: AttributedString
            do {
                bridged = try AttributedString(storage, including: AttributeScopes.SlateAttributes.self)
            } catch {
                Self.logger.error("Pont NSAttributedString -> AttributedString echoue, frappe ignoree : \(error)")
                return
            }

            let richText = RichText(attributedString: bridged)

            // Markdown natif (Phase 15) : voir `tryApplyMarkdownAutoformat` (`+Rendering.swift`).
            if tryApplyMarkdownAutoformat(richText: richText, textView: textView) {
                return
            }

            // Synchrone, a chaque frappe (voir la documentation de tete de fichier) :
            // seul un encodage JSON local, jamais l'ecriture disque ni le recalcul des
            // champs derives de la note.
            block.text = richText
            lastSyncedText = richText

            debouncer.schedule { [weak self] in
                self?.persist()
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            editorController.noteBlockDidEndEditing(block.id)
            flushPendingSave()
        }

        /// Menu "/" (Phase 6) : SEUL point d'entree de son etat, couvre a la fois une
        /// frappe et un simple deplacement de caret (fleches, clic -- "caret hors de la
        /// plage de requete" doit fermer le menu meme sans changement de texte).
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? RichTextEditingTextView else { return }
            let caretOffset = RichTextOffset(utf16Offset: textView.selectedRange().location, in: textView.string)
            editorController.updateSlashMenuState(for: block, plainText: textView.string, caretOffset: caretOffset)
            editorController.updatePageMentionState(for: block, plainText: textView.string, caretOffset: caretOffset)

            // Barre de formatage flottante (Phase 7, artboard P1 A) : voir la
            // documentation de `EditorController.inlineSelection`. Le rectangle LOCAL de
            // la selection (voir `selectionBoundingRectForFormatting()`) est repousse
            // dans la `coordinateSpace` partagee en lui ajoutant l'origine du cadre DEJA
            // connu de ce bloc (`EditorController.blockFrames`, alimente par
            // `BlockFramePreferenceKey`) -- non verifie pixel-exact dans une fenetre
            // reelle, voir le rapport de livraison.
            let range = RichTextRange(utf16Range: textView.selectedRange(), in: textView.string)
            let localRect = textView.selectionBoundingRectForFormatting()
            let sharedRect = localRect.map { rect in
                rect.offsetBy(
                    dx: editorController.blockFrames[block.id]?.origin.x ?? 0,
                    dy: editorController.blockFrames[block.id]?.origin.y ?? 0
                )
            }
            editorController.updateInlineSelection(for: block, range: range, rect: sharedRect)
        }

        // MARK: - Formatage inline (Phase 7, docs/07_typographie_formatage.md)

        func richTextViewShouldHandleToggleBold(selection: RichTextRange) -> Bool {
            editorController.toggleMark(.bold, in: block, range: selection)
            return true
        }

        func richTextViewShouldHandleToggleItalic(selection: RichTextRange) -> Bool {
            editorController.toggleMark(.italic, in: block, range: selection)
            return true
        }

        func richTextViewShouldHandleToggleUnderline(selection: RichTextRange) -> Bool {
            editorController.toggleMark(.underline, in: block, range: selection)
            return true
        }

        func richTextViewShouldHandleToggleStrikethrough(selection: RichTextRange) -> Bool {
            editorController.toggleMark(.strikethrough, in: block, range: selection)
            return true
        }

        func richTextViewShouldHandleToggleInlineCode(selection: RichTextRange) -> Bool {
            editorController.toggleMark(.inlineCode, in: block, range: selection)
            return true
        }

        func richTextViewShouldHandleLinkShortcut(selection: RichTextRange) -> Bool {
            editorController.requestLinkEditor(in: block, range: selection)
            return true
        }

        func richTextViewShouldHandleConvertToParagraph() -> Bool {
            editorController.convertBlock(block, to: .paragraph)
            return true
        }

        func richTextViewShouldHandleConvertToHeadingLevel(_ level: Int) -> Bool {
            let type: BlockType = switch level {
            case 1: .heading1
            case 2: .heading2
            default: .heading3
            }
            editorController.convertBlock(block, to: type)
            return true
        }

        // MARK: - RichTextBlockLifecycleDelegate (cycle de vie des blocs, sous-etape 5.3)
        //
        // Chaque methode adapte un evenement clavier generique (`RichTextEditingTextView`)
        // vers `EditorController`, en lui fournissant CE bloc -- aucune regle de cycle de
        // vie n'est decidee ICI, uniquement dans `EditorController`/`BlockLifecycle` (voir
        // leur documentation, "testable hors AppKit").

        func richTextViewShouldHandleReturn(caretOffset: RichTextOffset) -> Bool {
            editorController.handleEnter(in: block, caretOffset: caretOffset)
        }

        func richTextViewShouldHandleBackspaceAtStart() -> Bool {
            editorController.handleBackspaceAtBlockStart(block)
        }

        func richTextViewShouldHandleMoveUp(visualColumnX: CGFloat) -> Bool {
            editorController.handleMoveUp(from: block, visualColumnX: visualColumnX)
        }

        func richTextViewShouldHandleMoveDown(visualColumnX: CGFloat) -> Bool {
            editorController.handleMoveDown(from: block, visualColumnX: visualColumnX)
        }

        func richTextViewShouldHandleCancelEditing() -> Bool {
            editorController.handleEscape(in: block)
            return true
        }

        func richTextViewShouldHandleExtendSelectionUp() -> Bool {
            editorController.extendSelectionVertically(.up, from: block)
        }

        func richTextViewShouldHandleExtendSelectionDown() -> Bool {
            editorController.extendSelectionVertically(.down, from: block)
        }

        // MARK: - Menu de commandes "/" (Phase 6, sous-etape 6.4)

        func richTextViewShouldHandleSlashMenuMoveSelection(_ direction: BlockSelectionDirection) -> Bool {
            editorController.moveSlashMenuSelection(direction, in: block)
        }

        func richTextViewShouldHandleSlashMenuReturn() -> Bool {
            editorController.handleSlashMenuReturn(in: block)
        }

        func richTextViewShouldHandleSlashMenuEscape() -> Bool {
            editorController.handleSlashMenuEscape(in: block)
        }

        // Selecteur "@"/"[[" + lien interne (Phase 16) : `+PageMention.swift`.
        // MARK: - Markdown natif (Phase 15, docs/15_markdown_natif.md)

        func richTextViewShouldHandleMarkdownReturnTrigger(undoManager: UndoManager?) -> Bool {
            editorController.handleMarkdownReturnTrigger(in: block, undoManager: undoManager)
        }

        // `richTextViewShouldHandleMarkdownPaste` : voir `+Rendering.swift` (limite de
        // longueur de fichier, meme motif que `apply(_:to:)`/`persist()`).

        // MARK: - Indentation d'un item de liste (Phase 8, docs/08_blocs_speciaux.md)

        func richTextViewShouldHandleIndent() -> Bool {
            editorController.indentBlock(block)
        }

        func richTextViewShouldHandleOutdent() -> Bool {
            editorController.outdentBlock(block)
        }

        // MARK: - Ecriture modele -> vue
        //
        // `apply(_:to:)`/`persist()` et leurs helpers (`applySyntaxHighlighting`, le
        // `Logger` dedie) : voir `RichTextEditingRepresentable+Rendering.swift`, extrait
        // de ce fichier pour rester sous la limite de longueur de `CLAUDE.md` §5 (Phase
        // 8) -- meme motif exact que `RichTextEditingTextView+Typography.swift`.
    }
}

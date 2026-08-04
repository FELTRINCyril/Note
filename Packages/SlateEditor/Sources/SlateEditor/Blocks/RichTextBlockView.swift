import AppKit
import os
import SlateModel
import SlateUI
import SwiftData
import SwiftUI

/// Bloc paragraphe EDITABLE (docs/05_editeur_blocs.md, sous-etape 5.2) : `NSViewRepresentable`
/// autour d'un `NSTextView` TextKit 2 (`RichTextEditingTextView`), livrable central de
/// cette sous-etape (decision d'architecture de Phase 5, option 2 -- voir ce doc).
///
/// ## Contrat avec le modele
/// Lit et ecrit `Block.text` (`RichText`) via son accesseur, JAMAIS en reconstruisant un
/// `RichText` a partir de texte brut (`RichText.init(plainText:)`) : cela detruirait les
/// attributs inline que la Phase 7 exploitera. La conversion passe systematiquement par
/// `RichText.init(attributedString:)` a partir du contenu reel de l'`NSTextView`.
///
/// ## Sauvegarde : ce qui est synchrone, ce qui est debounce
/// `block.text` est ecrit en memoire a CHAQUE frappe (`Coordinator.textDidChange`) :
/// c'est un simple encodage JSON d'un paragraphe, documente comme negligeable par
/// `Block.textData`. Seules les operations couteuses -- `Note.refreshDerivedText()`,
/// `Note.modifiedAt` et l'ecriture reelle sur disque (`ModelContext.save()`) -- passent
/// par `BlockSaveDebouncer` et ne s'executent qu'au repos (600 ms sans frappe) ou au
/// FLUSH explicite.
///
/// ## Flush garanti (aucune frappe perdue)
/// Le flush est declenche a TROIS moments (docs/05_editeur_blocs.md, sous-etape 5.2,
/// point 3) :
/// 1. perte de focus du bloc (`Coordinator.textDidEndEditing`) ;
/// 2. la vue est retiree de la hierarchie (`dismantleNSView`) -- couvre a la fois la
///    fermeture de la note en cours ET le changement de note (`NoteDetailColumnView`
///    reconstruit l'arbre de blocs pour la nouvelle note, ce qui fait disparaitre du
///    `ForEach` tous les blocs de l'ancienne, donc demonte leur `RichTextBlockView`) ;
/// 3. transitivement, la fermeture de la fenetre/l'app, SI SwiftUI demonte la hierarchie
///    avant la sortie du processus -- comportement standard mais non garanti a 100 % par
///    ce code seul. En filet de securite : `block.text` est deja a jour en memoire au
///    moment ou l'autosave par defaut de `ModelContext` (active tant qu'il n'est pas
///    explicitement desactive) se declenche sur ses propres evenements systeme
///    (perte du statut de fenetre cle, passage de l'app en arriere-plan...), independamment
///    de ce debounce.
public struct RichTextBlockView: View {
    private let block: Block
    private let editorController: EditorController

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(block: Block, editorController: EditorController) {
        self.block = block
        self.editorController = editorController
    }

    public var body: some View {
        RichTextEditingRepresentable(
            block: block,
            editorController: editorController,
            modelContext: modelContext,
            reduceMotion: reduceMotion
        )
    }
}

/// Partie `NSViewRepresentable` proprement dite, separee de `RichTextBlockView` pour
/// que celle-ci reste une simple `View` (lisant son environnement dans `body`, pas dans
/// un type conforme a `NSViewRepresentable` ou l'acces a `context.environment` suit des
/// regles differentes).
private struct RichTextEditingRepresentable: NSViewRepresentable {
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
        context.coordinator.applyInitialContent(to: textView)
        textView.freezesCaretForReduceMotion = reduceMotion
        return textView
    }

    func updateNSView(_ nsView: RichTextEditingTextView, context: Context) {
        context.coordinator.updateModelContext(modelContext)
        nsView.freezesCaretForReduceMotion = reduceMotion
        nsView.applyTypography()
        context.coordinator.syncModelIfNeeded(into: nsView)
        // Cycle de vie des blocs (sous-etape 5.3) : si l'`EditorController` a une
        // requete de caret en attente pour CE bloc (nouveau bloc cree par Entree,
        // fusion, navigation haut/bas...), c'est ICI qu'elle est appliquee -- ce
        // `NSViewRepresentable` est garanti d'etre `updateNSView`-appele juste apres sa
        // creation par SwiftUI, donc meme un bloc qui vient d'apparaitre dans le
        // `ForEach` recoit bien sa requete au tour de rendu ou elle a ete emise.
        if let request = editorController.consumePendingCaretRequest(for: block.id) {
            nsView.applyCaretPlacement(request.placement)
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
        private let block: Block
        private let editorController: EditorController
        private var modelContext: ModelContext
        private let debouncer = BlockSaveDebouncer()

        /// Dernier contenu connu comme etant IDENTIQUE entre le modele et la vue.
        /// Sert a distinguer "le modele a change depuis l'exterieur" (il faut repousser
        /// le nouveau contenu dans le NSTextView) de "le modele a change parce qu'on
        /// vient d'y ecrire depuis cette meme frappe" (il ne faut RIEN repousser, ca
        /// couperait la composition et deplacerait le caret) -- voir
        /// `syncModelIfNeeded`.
        private var lastSyncedText: RichText?

        /// Vrai pendant qu'on ecrit programmatiquement dans le `NSTextStorage` (mise a
        /// jour venue du modele, pas de l'utilisateur). Garde-fou defensif contre un
        /// double traitement dans `textDidChange` -- `NSTextStorage.setAttributedString`
        /// ne declenche normalement pas la notification `NSText.didChangeNotification`
        /// (elle est postee par `NSTextView.didChangeText()`, jamais appele ici), mais ce
        /// drapeau documente explicitement l'intention plutot que de compter
        /// silencieusement sur ce detail d'implementation AppKit.
        private var isApplyingModelToView = false

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
        }

        /// Repousse le contenu du modele dans la vue SEULEMENT s'il a change depuis
        /// l'exterieur (voir la documentation de `lastSyncedText`). Appele a chaque
        /// `updateNSView`, donc a chaque re-rendu SwiftUI de ce bloc.
        func syncModelIfNeeded(into textView: RichTextEditingTextView) {
            let currentModelText = block.text ?? RichText()
            guard currentModelText != lastSyncedText else { return }
            apply(currentModelText, to: textView)
            lastSyncedText = currentModelText
        }

        /// Execute immediatement toute sauvegarde en attente. Voir la documentation de
        /// `RichTextBlockView` pour les trois moments ou c'est appele.
        func flushPendingSave() {
            debouncer.flush()
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

        // MARK: - RichTextBlockLifecycleDelegate (cycle de vie des blocs, sous-etape 5.3)
        //
        // Chaque methode adapte un evenement clavier generique (`RichTextEditingTextView`)
        // vers `EditorController`, en lui fournissant CE bloc -- aucune regle de cycle de
        // vie n'est decidee ICI, uniquement dans `EditorController`/`BlockLifecycle` (voir
        // leur documentation, "testable hors AppKit").

        func richTextViewShouldHandleReturn(caretOffset: Int) -> Bool {
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

        // MARK: - Ecriture modele -> vue

        /// Logger dedie a ce pont AppKit <-> `AttributedString` (voir `apply(_:to:)` et
        /// `textDidChange(_:)`) : les deux SEULS points de ce fichier qui traversent la
        /// frontiere `NSAttributedString`, donc les deux SEULS ou une perte silencieuse
        /// d'attribut custom pourrait se reproduire si le scope explicite etait oublie
        /// un jour.
        private static let logger = Logger(subsystem: "com.gemaddis.slate.SlateEditor", category: "RichTextBridging")

        private func apply(_ text: RichText, to textView: NSTextView) {
            // Pont AttributedString -> NSAttributedString AVEC le scope explicite
            // (symmetrique de `textDidChange(_:)` ci-dessus, meme raison, meme risque
            // de perte silencieuse sans `including:`). Throwing : geree explicitement.
            // Si la conversion echoue, on NE POUSSE RIEN dans le `NSTextView` -- le
            // contenu affiche reste celui d'avant plutot qu'une version amputee.
            let bridged: NSAttributedString
            do {
                bridged = try NSAttributedString(text.attributedString, including: AttributeScopes.SlateAttributes.self)
            } catch {
                Self.logger.error("Pont AttributedString -> NSAttributedString echoue, contenu NON repousse : \(error)")
                return
            }

            isApplyingModelToView = true
            textView.textStorage?.setAttributedString(bridged)
            isApplyingModelToView = false
        }

        /// Le point de sauvegarde UNIQUE (voir `BlockTextCommit`) : recalcule les champs
        /// derives de la note, horodate la modification, puis ecrit reellement sur
        /// disque. Invoque uniquement au flush du debounce -- jamais a chaque frappe.
        private func persist() {
            BlockTextCommit.flush(block: block)
            try? modelContext.save()
        }
    }
}

/// Contenu commun aux previews : `RichTextBlockView` lit `@Environment(\.modelContext)`
/// (pour la sauvegarde debouncee), un conteneur SwiftData en memoire est donc requis --
/// contrairement aux previews en lecture seule de la Phase 5.1, qui n'en avaient pas
/// besoin. Pas de `try!`/force-unwrap (CLAUDE.md §5) : un echec de creation du
/// conteneur (improbable en memoire) retombe sur un texte de diagnostic plutot qu'un
/// crash de preview.
private struct RichTextBlockPreviewHost: View {
    let text: RichText?

    var body: some View {
        let note = Note(title: "Apercu")
        let block = Block(type: .paragraph, text: text, note: note)
        note.blocks = [block]
        return Group {
            if let container = try? SlateContainer.make(inMemory: true) {
                RichTextBlockView(block: block, editorController: EditorController(note: note))
                    .modelContainer(container)
            } else {
                Text("Conteneur SwiftData indisponible pour cette preview")
            }
        }
        .padding()
        .frame(width: 500)
        .background(SlateColor.bgEditor)
    }
}

#Preview("RichTextBlockView - clair") {
    RichTextBlockPreviewHost(text: RichText(plainText: "Un bloc editable, TextKit 2."))
        .environment(\.colorScheme, .light)
}

#Preview("RichTextBlockView - vide") {
    // Bloc vide isole : AUCUN placeholder ici, il n'est peint que par `BlockContainer`
    // (voir `BlockTreeView`), pas par `RichTextBlockView` lui-meme. Cette preview verifie
    // uniquement que le NSTextView reste utilisable (caret visible) sans contenu.
    RichTextBlockPreviewHost(text: nil)
        .environment(\.colorScheme, .dark)
}

import Foundation
import SlateModel

/// Point de FLUSH unique d'une edition de bloc texte (docs/05_editeur_blocs.md,
/// sous-etape 5.2, points 3 et 6). Isole d'AppKit et de `ModelContext` : ne manipule que
/// des objets `SlateModel` deja en memoire, pour rester testable sans construire de
/// hierarchie `NSView` ni de conteneur SwiftData.
///
/// ## Ce que ce type NE fait PAS
/// Il n'ecrit pas `block.text` : cette affectation reste synchrone, a CHAQUE frappe,
/// faite directement par `RichTextBlockView.Coordinator.textDidChange` -- son cout (un
/// encodage JSON d'un paragraphe) est documente comme negligeable par
/// `Block.textData`. Ce que ce type porte, ce sont les DEUX operations qui, elles,
/// doivent rester DEBOUNCEES : l'horodatage de modification de la note et le recalcul
/// de ses champs derives. C'est exactement le contrat que `Note.refreshDerivedText()`
/// demande a l'editeur de blocs : "l'editeur doit appeler `refreshDerivedText()` depuis
/// son unique point de sauvegarde ... et depuis cet unique point seulement" -- ce type
/// EST ce point unique.
@MainActor
public enum BlockTextCommit {
    /// A appeler au FLUSH du debounce (`BlockSaveDebouncer.flush()`), jamais a chaque
    /// frappe : met a jour `Note.modifiedAt`, puis recalcule `plainText`/`snippetText`
    /// via `Note.refreshDerivedText()`.
    ///
    /// Sans effet si `block.note` est `nil` (bloc orphelin : ne devrait pas arriver en
    /// usage normal, mais ne doit pas planter pour autant -- pas de force-unwrap).
    ///
    /// - Parameter now: horodatage a ecrire dans `Note.modifiedAt`. Parametre injecte
    ///   (par defaut `.now`) pour que les tests puissent verifier la valeur exacte
    ///   ecrite sans dependre de l'horloge systeme au moment de l'assertion.
    public static func flush(block: Block, now: Date = .now) {
        guard let note = block.note else { return }
        flush(note: note, now: now)
    }

    /// Variante directe sur `Note`, pour les appelants qui n'ont pas necessairement un
    /// `Block` encore attache sous la main au moment du flush -- typiquement
    /// `EditorController` (sous-etape 5.3) apres une operation qui a pu DETACHER un
    /// bloc de sa note (fusion, suppression de bloc vide). `flush(block:)` ci-dessus
    /// delegue a cette fonction : POINT UNIQUE reel de recalcul, comme documente en
    /// tete de fichier -- aucun second chemin d'ecriture.
    public static func flush(note: Note, now: Date = .now) {
        note.modifiedAt = now
        note.refreshDerivedText()
    }

    /// Variante de `flush(note:now:)` qui met a jour `Note.modifiedAt` SANS recalculer
    /// `plainText`/`snippetText` -- reservee AUX SEULS appelants qui viennent d'inserer
    /// un bloc de texte VIDE et RIEN d'autre (voir `EditorController.
    /// appendTrailingParagraph`/`insertBlockBelow`, les deux SEULS sites d'appel).
    ///
    /// ## Pourquoi c'est correct, pas un raccourci qui masque un probleme
    /// `Note.refreshDerivedText()` filtre deja les blocs vides de son calcul
    /// (`.filter { !$0.isEmpty }`, voir `SlateModel/Note.swift`) : ajouter un bloc VIDE
    /// ne peut donc, PAR CONSTRUCTION, jamais changer `plainText`/`snippetText`. Les
    /// recalculer serait un travail prouvablement inutile -- pourtant paye a CHAQUE
    /// insertion avant cette optimisation : n insertions successives en fin de note (une
    /// frappe d'Entree tenue) recalculaient `plainText` sur la TOTALITE des blocs a
    /// chaque fois, un cout cumule quadratique mesure par
    /// `BlockPerformanceTests.appendTrailingParagraphScaling` (revue finale de Phase 5) --
    /// la seule cause residuelle une fois `BlockOrdering` lui-meme rendu lineaire (voir
    /// sa documentation de tete de fichier).
    ///
    /// `modifiedAt` reste mis a jour NORMALEMENT : la note EST modifiee structurellement,
    /// seul le texte DERIVE ne peut pas avoir change. `assert` (compile a vide en
    /// Release, cout nul en production) : si `appendTrailingParagraph`/`insertBlockBelow`
    /// inseraient un jour du texte non vide, cette fonction ne doit PLUS etre appelee a
    /// leur place -- le crash en debug/tests le signalerait immediatement plutot que de
    /// laisser `plainText` silencieusement perime.
    ///
    /// - Parameter insertedText: le texte du bloc QUI VIENT D'ETRE INSERE par l'appelant
    ///   -- verifie explicitement qu'il est bien vide, pour que cette fonction ne
    ///   puisse jamais etre invoquee par erreur sur un chemin qui, lui, doit recalculer.
    public static func flushWithoutRefreshingDerivedText(note: Note, insertedText: RichText, now: Date = .now) {
        assert(
            insertedText.isEmpty,
            "flushWithoutRefreshingDerivedText suppose un bloc INSERE VIDE -- utiliser flush(note:) sinon"
        )
        note.modifiedAt = now
    }
}

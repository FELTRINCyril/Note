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
}

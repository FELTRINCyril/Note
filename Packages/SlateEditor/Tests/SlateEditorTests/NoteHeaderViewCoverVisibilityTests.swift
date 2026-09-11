import Testing
@testable import SlateEditor

/// Verifie le branchement du reglage "Afficher la couverture des notes" (design P4,
/// artboard A, `ThemeManager.showsNoteCover`) sur `NoteHeaderView` (Phase 13 "suite" --
/// avant ce branchement, le reglage etait stocke mais ne pilotait rien).
///
/// Teste la regle PURE `NoteHeaderView.shouldDisplayCover(showsNoteCover:hasCoverImageData:)`
/// plutot que `NoteHeaderView.displaysCover` directement : cette derniere lit
/// `@Environment(ThemeManager.self)`, qui declenche un crash a la lecture hors d'une
/// hierarchie SwiftUI reellement rendue (aucun ancetre `.environment(ThemeManager.shared)`
/// dans un contexte de test). La regle extraite est strictement equivalente et sans cette
/// dependance.
@Suite("NoteHeaderView - visibilite de la couverture (reglage Afficher la couverture)")
struct NoteHeaderViewCoverVisibilityTests {
    @Test("Reglage actif ET couverture presente : la couverture s'affiche")
    func displaysCoverWhenSettingOnAndCoverPresent() {
        #expect(NoteHeaderView.shouldDisplayCover(showsNoteCover: true, hasCoverImageData: true))
    }

    @Test("Reglage desactive : la couverture ne s'affiche jamais, meme si la note en a une")
    func hidesCoverWhenSettingOff() {
        #expect(!NoteHeaderView.shouldDisplayCover(showsNoteCover: false, hasCoverImageData: true))
    }

    @Test("Pas de couverture sur la note : rien a afficher, quel que soit le reglage")
    func noCoverDataMeansNothingToDisplay() {
        #expect(!NoteHeaderView.shouldDisplayCover(showsNoteCover: true, hasCoverImageData: false))
        #expect(!NoteHeaderView.shouldDisplayCover(showsNoteCover: false, hasCoverImageData: false))
    }

    /// Le reglage ne doit jamais FAIRE APPARAITRE une couverture qui n'existe pas -- il
    /// ne fait que masquer une couverture existante. Verifie que l'implication n'est
    /// jamais inversee (pas de court-circuit qui laisserait `showsNoteCover` suffire seul).
    @Test("Le reglage seul, sans donnee de couverture, ne suffit jamais")
    func settingAloneNeverSuffices() {
        #expect(!NoteHeaderView.shouldDisplayCover(showsNoteCover: true, hasCoverImageData: false))
    }
}

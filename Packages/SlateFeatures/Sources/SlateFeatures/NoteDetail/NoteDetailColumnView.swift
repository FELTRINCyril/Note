import SwiftUI
import SlateModel
import SlateEditor
import SlateServices

/// Colonne detail : bascule entre l'etat vide (`NoteDetailColumnPlaceholderView`,
/// deja livre en Phase 3), l'ecran de verrou (`LockedNoteView`, Phase 12) et le rendu
/// de la note selectionnee (`SlateEditor.NoteDocumentView`, Phase 5.1).
///
/// Point d'integration unique demande par la Phase 5.1 (`docs/05_editeur_blocs.md`,
/// sous-etape 5.1, point 6) : c'est ICI, et seulement ici, que `SlateFeatures` fournit
/// a `SlateEditor` les chaines localisees (`NoteEditorStrings`) et la ligne de
/// metadonnees deja formatee (`NoteHeaderMetadataFormatter`) -- `SlateEditor` lui-meme
/// ne sait ni localiser une chaine (voir `NoteEditorStrings`) ni formater une date
/// (sens des dependances, `docs/00_architecture.md`).
///
/// **Regle de securite de cette phase (Phase 12, `docs/12_verrouillage.md`)** : quand
/// `note.isLocked`, `SlateEditor.NoteDocumentView` (qui lit `note.blocks` -- voir
/// `BlockOrdering.topLevelBlocks(of:)`) n'est PAS meme construite. C'est ce branchement
/// qui garantit qu'aucun chemin de code ne lit le contenu d'une note verrouillee, pas
/// une precaution a l'interieur de `LockedNoteView` elle-meme.
struct NoteDetailColumnView: View {
    @Environment(\.appState) private var appState
    @Environment(\.lockService) private var lockService
    @State private var showsComingSoonAlert = false
    @State private var comingSoonMessage = ""
    @State private var isUnlockPasswordSheetPresented = false

    /// Seuil de reverrouillage automatique par inactivite (Phase 12 : "apres 5 minutes
    /// d'inactivite"). Meme cle que `LockSettingsTabView` : un reglage modifie dans les
    /// reglages s'applique immediatement ici, sans branchement supplementaire.
    @AppStorage("lock.autoRelockThresholdSeconds") private var autoRelockThresholdSeconds: Double = 300

    /// Frequence de verification de l'inactivite : suffisamment fine pour qu'un seuil
    /// de 5 minutes ne deborde jamais de plus de 20 secondes, sans reveiller le
    /// processus trop souvent.
    private static let inactivityCheckInterval: TimeInterval = 20

    var body: some View {
        Group {
            if let note = appState.selectedNote {
                if note.isLocked {
                    LockedNoteView(
                        noteTitle: displayedTitle(for: note),
                        passwordHint: lockService.passwordHint,
                        isBiometricsAvailable: lockService.isBiometricsAvailable,
                        onUnlockWithBiometrics: { unlockWithBiometrics(note) },
                        onUsePassword: { isUnlockPasswordSheetPresented = true }
                    )
                } else {
                    NoteDocumentView(
                        note: note,
                        metadataLine: metadataLine(for: note),
                        strings: strings,
                        onAddIcon: {
                            presentComingSoon(String(localized: "noteDetail.addIcon.comingSoon", bundle: .module))
                        },
                        onAddCover: {
                            presentComingSoon(String(localized: "noteDetail.addCover.comingSoon", bundle: .module))
                        }
                    )
                }
            } else {
                NoteDetailColumnPlaceholderView()
            }
        }
        .alert(
            String(localized: "noteDetail.comingSoon.title", bundle: .module),
            isPresented: $showsComingSoonAlert
        ) {
            Button(String(localized: "action.ok", bundle: .module), role: .cancel) {}
        } message: {
            Text(comingSoonMessage)
        }
        .sheet(isPresented: $isUnlockPasswordSheetPresented) {
            UnlockPasswordSheet(
                onSubmit: { password in unlockWithPassword(appState.selectedNote, password: password) },
                onCancel: { isUnlockPasswordSheetPresented = false }
            )
        }
        // Reverrouillage automatique "a la fermeture de la note" (`docs/12_verrouillage.md`) :
        // declenche des que la note affichee change (y compris vers "aucune note"),
        // AVANT que la nouvelle note ne soit rendue.
        .onChange(of: appState.selectedNote) { oldValue, _ in
            AutoRelockCoordinator.noteDidLoseFocus(oldValue, appState: appState, lockService: lockService)
        }
        // Reverrouillage automatique par inactivite : voir `SystemIdleTime`/
        // `AutoRelockCoordinator.relockIfInactive`. No-op tant qu'aucune note n'est
        // deverrouillee cette session (`AppState.recentlyUnlockedNotes`).
        .onReceive(Timer.publish(every: Self.inactivityCheckInterval, on: .main, in: .common).autoconnect()) { _ in
            AutoRelockCoordinator.relockIfInactive(
                autoRelock: InactivityAutoRelock(threshold: autoRelockThresholdSeconds),
                idleSeconds: SystemIdleTime.seconds(),
                appState: appState,
                lockService: lockService
            )
        }
    }

    // MARK: - Deverrouillage

    private func unlockWithBiometrics(_ note: Note) {
        Task { @MainActor in
            let reason = String(localized: "lock.biometrics.reason", bundle: .module)
            guard await lockService.unlock(note, usingBiometricsReason: reason) else { return }
            appState.markNoteRecentlyUnlocked(note)
        }
    }

    /// Retourne le succes a `UnlockPasswordSheet` (mot de passe incorrect = echec
    /// NORMAL de ce flux, pas une anomalie -- voir `LockService.unlock(_:password:)`).
    private func unlockWithPassword(_ note: Note?, password: String) -> Bool {
        guard let note else { return false }
        guard lockService.unlock(note, password: password) else { return false }
        appState.markNoteRecentlyUnlocked(note)
        isUnlockPasswordSheetPresented = false
        return true
    }

    private func displayedTitle(for note: Note) -> String {
        note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(localized: "noteDetail.title.placeholder", bundle: .module)
            : note.title
    }

    private func metadataLine(for note: Note) -> String {
        let wordCount = WordCounter.wordCount(in: note.plainText)
        return NoteHeaderMetadataFormatter.string(modifiedAt: note.modifiedAt, wordCount: wordCount)
    }

    private var strings: NoteEditorStrings {
        NoteEditorStrings(
            untitledPlaceholder: String(localized: "noteDetail.title.placeholder", bundle: .module),
            addIconLabel: String(localized: "noteDetail.addIcon.label", bundle: .module),
            addIconAccessibilityLabel: String(localized: "noteDetail.addIcon.accessibilityLabel", bundle: .module),
            addCoverLabel: String(localized: "noteDetail.addCover.label", bundle: .module),
            addCoverAccessibilityLabel: String(localized: "noteDetail.addCover.accessibilityLabel", bundle: .module),
            noteIconAccessibilityLabel: String(localized: "noteDetail.icon.accessibilityLabel", bundle: .module),
            noteCoverAccessibilityLabel: String(localized: "noteDetail.cover.accessibilityLabel", bundle: .module),
            unsupportedBlockLabelPrefix: String(localized: "noteDetail.unsupportedBlock.prefix", bundle: .module)
        )
    }

    private func presentComingSoon(_ message: String) {
        comingSoonMessage = message
        showsComingSoonAlert = true
    }
}

#Preview("NoteDetailColumnView - aucune note") {
    NoteDetailColumnView()
        .frame(width: 900, height: 700)
}

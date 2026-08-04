import Foundation
import Testing

@testable import SlateEditor

/// Double de test de `BlockSaveDebounceScheduling` : capture le travail programme SANS
/// jamais attendre de vraies millisecondes (voir la documentation de ce protocole) --
/// c'est ce qui rend `BlockSaveDebouncerTests` deterministe et instantane, exigence
/// explicite de la tache ("horloge injectee plutot qu'un Task.sleep en dur").
@MainActor
private final class RecordingDebounceScheduler: BlockSaveDebounceScheduling {
    private(set) var scheduleCallCount = 0
    private(set) var lastInterval: TimeInterval?
    private var pendingAction: (@MainActor () -> Void)?
    private var lastToken: RecordingToken?

    func schedule(after interval: TimeInterval, action: @escaping @MainActor () -> Void) -> any BlockSaveDebounceToken {
        scheduleCallCount += 1
        lastInterval = interval
        pendingAction = action
        let token = RecordingToken { [weak self] in self?.pendingAction = nil }
        lastToken = token
        return token
    }

    /// Simule l'ecoulement du delai : declenche le travail programme le plus recent
    /// (equivalent au tick du minuteur reel), a moins qu'il n'ait ete annule depuis.
    @discardableResult
    func fireIfScheduled() -> Bool {
        guard let action = pendingAction else { return false }
        pendingAction = nil
        action()
        return true
    }

    var isCurrentTokenCancelled: Bool {
        lastToken?.isCancelled ?? false
    }

    private final class RecordingToken: BlockSaveDebounceToken {
        private let onCancel: () -> Void
        private(set) var isCancelled = false
        init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
        func cancel() {
            isCancelled = true
            onCancel()
        }
    }
}

@MainActor
@Suite("BlockSaveDebouncer")
struct BlockSaveDebouncerTests {
    @Test("schedule() ne s'execute pas immediatement : il faut attendre le tick du minuteur")
    func scheduleDoesNotRunSynchronously() {
        let scheduler = RecordingDebounceScheduler()
        let debouncer = BlockSaveDebouncer(interval: 42, scheduler: scheduler)
        var didRun = false

        debouncer.schedule { didRun = true }

        #expect(didRun == false)
        #expect(scheduler.lastInterval == 42)
    }

    @Test("Deux schedule() rapproches n'executent qu'UNE seule fois, avec la DERNIERE action")
    func rapidSchedulesCollapseIntoOne() {
        let scheduler = RecordingDebounceScheduler()
        let debouncer = BlockSaveDebouncer(scheduler: scheduler)
        var runCount = 0
        var lastValue = 0

        debouncer.schedule {
            runCount += 1
            lastValue = 1
        }
        debouncer.schedule {
            runCount += 1
            lastValue = 2
        }

        scheduler.fireIfScheduled()

        #expect(runCount == 1)
        #expect(lastValue == 2)
    }

    @Test("flush() execute immediatement le travail en attente, sans attendre le minuteur")
    func flushRunsImmediately() {
        let scheduler = RecordingDebounceScheduler()
        let debouncer = BlockSaveDebouncer(scheduler: scheduler)
        var didRun = false

        debouncer.schedule { didRun = true }
        let didFlush = debouncer.flush()

        #expect(didFlush)
        #expect(didRun)
        // Le minuteur en attente a bien ete annule : un tick tardif ne doit pas
        // executer l'action une seconde fois.
        #expect(scheduler.isCurrentTokenCancelled)
    }

    @Test("flush() sans travail en attente ne fait rien et le signale")
    func flushWithNothingPendingIsNoOp() {
        let scheduler = RecordingDebounceScheduler()
        let debouncer = BlockSaveDebouncer(scheduler: scheduler)

        let didFlush = debouncer.flush()

        #expect(didFlush == false)
    }

    @Test("Un tick de minuteur apres un flush() ne re-execute pas l'action")
    func tickAfterFlushDoesNotRerun() {
        let scheduler = RecordingDebounceScheduler()
        let debouncer = BlockSaveDebouncer(scheduler: scheduler)
        var runCount = 0

        debouncer.schedule { runCount += 1 }
        debouncer.flush()
        scheduler.fireIfScheduled()

        #expect(runCount == 1)
    }

    @Test("cancelWithoutFlushing() abandonne le travail en attente sans jamais l'executer")
    func cancelWithoutFlushingDiscardsPendingWork() {
        let scheduler = RecordingDebounceScheduler()
        let debouncer = BlockSaveDebouncer(scheduler: scheduler)
        var didRun = false

        debouncer.schedule { didRun = true }
        debouncer.cancelWithoutFlushing()
        scheduler.fireIfScheduled()
        let didFlush = debouncer.flush()

        #expect(didRun == false)
        #expect(didFlush == false)
    }

    @Test("Apres l'execution normale du minuteur, un nouveau schedule() reprogramme correctement")
    func canScheduleAgainAfterCompletion() {
        let scheduler = RecordingDebounceScheduler()
        let debouncer = BlockSaveDebouncer(scheduler: scheduler)
        var runCount = 0

        debouncer.schedule { runCount += 1 }
        scheduler.fireIfScheduled()
        debouncer.schedule { runCount += 1 }
        scheduler.fireIfScheduled()

        #expect(runCount == 2)
    }
}

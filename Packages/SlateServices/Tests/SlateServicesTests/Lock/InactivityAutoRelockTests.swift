import Foundation
import Testing

@testable import SlateServices

/// Verifie les bornes exactes du re-verrouillage automatique par inactivite.
struct InactivityAutoRelockTests {
    private let referenceDate = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test
    func doesNotRelockBeforeTheThresholdIsReached() {
        let policy = InactivityAutoRelock(threshold: 300)
        let lastActivity = referenceDate
        let now = referenceDate.addingTimeInterval(299)

        #expect(!policy.shouldRelock(lastActivityAt: lastActivity, now: now))
    }

    @Test
    func relocksExactlyAtTheThreshold() {
        let policy = InactivityAutoRelock(threshold: 300)
        let lastActivity = referenceDate
        let now = referenceDate.addingTimeInterval(300)

        #expect(policy.shouldRelock(lastActivityAt: lastActivity, now: now))
    }

    @Test
    func relocksAfterTheThreshold() {
        let policy = InactivityAutoRelock(threshold: 300)
        let lastActivity = referenceDate
        let now = referenceDate.addingTimeInterval(301)

        #expect(policy.shouldRelock(lastActivityAt: lastActivity, now: now))
    }

    @Test
    func defaultThresholdIsFiveMinutes() {
        #expect(InactivityAutoRelock.defaultThreshold == 5 * 60)
        #expect(InactivityAutoRelock().threshold == 5 * 60)
    }

    @Test
    func activityAfterNowNeverTriggersRelock() {
        let policy = InactivityAutoRelock(threshold: 300)
        let lastActivity = referenceDate
        let now = referenceDate.addingTimeInterval(-10)

        #expect(!policy.shouldRelock(lastActivityAt: lastActivity, now: now))
    }
}

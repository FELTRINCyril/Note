import Foundation
import Testing
@testable import SlateFeatures

/// Calculs purs de `TrashRetentionPolicy` (design P3, artboard B : purge a 30 jours).
@Suite("TrashRetentionPolicy")
struct TrashRetentionPolicyTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    @Test("Expiration = trashedAt + 30 jours")
    func expirationDateIsThirtyDaysLater() throws {
        let trashedAt = try date(2026, 1, 1)
        let expected = try date(2026, 1, 31)

        #expect(TrashRetentionPolicy.expirationDate(trashedAt: trashedAt, calendar: calendar) == expected)
    }

    @Test("Une note en corbeille depuis 31 jours est deja expiree")
    func isExpiredAfterThirtyOneDays() throws {
        let trashedAt = try date(2026, 1, 1)
        let now = try date(2026, 2, 1)

        #expect(TrashRetentionPolicy.isExpired(trashedAt: trashedAt, now: now, calendar: calendar))
    }

    @Test("Une note en corbeille depuis 2 jours n'est pas expiree")
    func isNotExpiredAfterTwoDays() throws {
        let trashedAt = try date(2026, 1, 1)
        let now = try date(2026, 1, 3)

        #expect(!TrashRetentionPolicy.isExpired(trashedAt: trashedAt, now: now, calendar: calendar))
        #expect(TrashRetentionPolicy.remainingDays(trashedAt: trashedAt, now: now, calendar: calendar) == 28)
        #expect(TrashRetentionPolicy.elapsedDays(trashedAt: trashedAt, now: now, calendar: calendar) == 2)
    }
}

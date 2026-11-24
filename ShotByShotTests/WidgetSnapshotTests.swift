import Foundation
import Testing
@testable import ShotByShot

struct WidgetSnapshotTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func snapshot(portion: Int = 3, isDoneToday: Bool = true, nights: Int = 12, on day: Date) -> WidgetSnapshot {
        WidgetSnapshot(
            hasAccess: true, portion: portion, isDoneToday: isDoneToday,
            nights: nights, day: calendar.startOfDay(for: day)
        )
    }

    @Test func doneTodayShowsTheNightsOfTheMonth() {
        let state = snapshot(on: date(2026, 11, 13)).state(at: date(2026, 11, 13, hour: 23), calendar: calendar)
        #expect(state == .done(nights: 12))
    }

    @Test func doneEndsAtMidnight() {
        let state = snapshot(on: date(2026, 11, 13)).state(at: date(2026, 11, 14, hour: 0), calendar: calendar)
        #expect(state == .waiting(3))
    }

    @Test func aWaitingPortionIsShownUntilTheDayIsDone() {
        let state = snapshot(isDoneToday: false, on: date(2026, 11, 13))
            .state(at: date(2026, 11, 13), calendar: calendar)
        #expect(state == .waiting(3))
    }

    @Test func anEmptyInboxKeepsTheNightsWithinTheMonth() {
        let state = snapshot(portion: 0, on: date(2026, 11, 13)).state(at: date(2026, 11, 14), calendar: calendar)
        #expect(state == .done(nights: 12))
    }

    @Test func aNewMonthStartsWithNoNights() {
        // Computed on November 30; shown after midnight with nothing left in the inbox.
        let state = snapshot(portion: 0, on: date(2026, 11, 30)).state(at: date(2026, 12, 1, hour: 0), calendar: calendar)
        #expect(state == .done(nights: 0))
    }

    @Test func withoutAccessTheWidgetAsksToSetUp() {
        #expect(WidgetSnapshot().state(at: date(2026, 11, 13), calendar: calendar) == .needsSetup)
    }

    @Test func survivesARoundTripThroughDefaults() throws {
        let name = "WidgetSnapshotTests"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let written = snapshot(on: date(2026, 11, 13))
        written.write(to: defaults)
        #expect(WidgetSnapshot(defaults: defaults) == written)
    }
}

import Foundation
import Testing
@testable import ShotByShot

struct RemindOptionTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Friday, November 13, 2026, noon.
    var friday: Date { date(2026, 11, 13) }

    @Test func optionsOnAFridayNoon() {
        #expect(RemindOption.tonight.date(after: friday, calendar: calendar) == date(2026, 11, 13, 20))
        #expect(RemindOption.tomorrow.date(after: friday, calendar: calendar) == date(2026, 11, 14, 9))
        #expect(RemindOption.weekend.date(after: friday, calendar: calendar) == date(2026, 11, 14, 10))
        #expect(RemindOption.nextWeek.date(after: friday, calendar: calendar) == date(2026, 11, 16, 9))
    }

    @Test func tonightIsNotOfferedAfterEight() {
        #expect(RemindOption.tonight.date(after: date(2026, 11, 13, 20), calendar: calendar) == nil)
        #expect(RemindOption.tonight.date(after: date(2026, 11, 13, 23), calendar: calendar) == nil)
        let late = RemindOption.available(after: date(2026, 11, 13, 21), calendar: calendar).map(\.option)
        #expect(late == [.tomorrow, .weekend, .nextWeek])
    }

    @Test func weekendOnASaturday() {
        // Saturday morning: today at 10. Saturday afternoon: next Saturday.
        #expect(RemindOption.weekend.date(after: date(2026, 11, 14, 8), calendar: calendar) == date(2026, 11, 14, 10))
        #expect(RemindOption.weekend.date(after: date(2026, 11, 14, 15), calendar: calendar) == date(2026, 11, 21, 10))
    }

    @Test func nextWeekIsTheComingMonday() {
        #expect(RemindOption.nextWeek.date(after: date(2026, 11, 15, 18), calendar: calendar) == date(2026, 11, 16, 9))
        #expect(RemindOption.nextWeek.date(after: date(2026, 11, 16, 10), calendar: calendar) == date(2026, 11, 23, 9))
    }

    @Test func everyOfferedDateIsInTheFuture() {
        for hour in [0, 9, 10, 19, 20, 23] {
            for day in 9...15 {
                let now = date(2026, 11, day, hour)
                for (_, offered) in RemindOption.available(after: now, calendar: calendar) {
                    #expect(offered > now)
                }
            }
        }
    }

    @Test func remindCountsAsKeptAndCanBeUndone() {
        var engine = SessionEngine(assetIDs: ["a", "b"])
        let when = date(2026, 11, 14, 9)
        engine.decide(.remind(.buy, when))
        engine.decide(.delete)
        #expect(engine.keptCount == 1)
        #expect(engine.assetIDsMarkedForDeletion == ["b"])
        engine.undo()
        #expect(engine.undo()?.decision == .remind(.buy, when))
    }
}

struct HideDecisionTests {
    @Test func hidingIsNeitherKeptNorDeleted() {
        var engine = SessionEngine(assetIDs: ["a", "b", "c"])
        engine.decide(.hide)
        engine.decide(.keep(.private))
        engine.decide(.delete)
        #expect(engine.keptCount == 1)
        #expect(engine.assetIDsMarkedForDeletion == ["c"])
        #expect(engine.isFinished)
    }
}

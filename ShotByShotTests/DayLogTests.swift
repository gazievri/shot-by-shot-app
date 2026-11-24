import Foundation
import SwiftData
import Testing
@testable import ShotByShot

@MainActor
struct DayLogTests {
    let context = ModelContext(ModelContainer.shotByShot(inMemory: true))

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }

    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func sameDayReusesOneLog() throws {
        let morning = try context.dayLog(for: date(2026, 11, 13, hour: 8), calendar: calendar)
        let evening = try context.dayLog(for: date(2026, 11, 13, hour: 22), calendar: calendar)
        #expect(morning === evening)
        #expect(morning.day == date(2026, 11, 13, hour: 0))
        #expect(try context.fetchCount(FetchDescriptor<DayLog>()) == 1)
    }

    @Test func completedSessionIsCounted() throws {
        let log = try context.dayLog(for: date(2026, 11, 13), calendar: calendar)
        log.add(kept: 2, deleted: 1, freedBytes: 500, completed: true)
        #expect(log.completedSessions == 1)
        #expect(log.reviewed == 3)
        #expect(log.kept == 2)
        #expect(log.deleted == 1)
        #expect(log.freedBytes == 500)
    }

    @Test func sessionClosedEarlyKeepsDecisionsButIsNotCompleted() throws {
        let log = try context.dayLog(for: date(2026, 11, 13), calendar: calendar)
        log.add(kept: 1, deleted: 0, freedBytes: 0, completed: false)
        #expect(log.completedSessions == 0)
        #expect(log.reviewed == 1)
    }

    @Test func statsCoverCurrentWeekAndMonth() throws {
        // Friday, November 13, 2026. The week starts on Monday, November 9.
        let today = date(2026, 11, 13)
        try context.dayLog(for: today, calendar: calendar)
            .add(kept: 2, deleted: 1, freedBytes: 100, completed: true)
        try context.dayLog(for: date(2026, 11, 9), calendar: calendar)
            .add(kept: 0, deleted: 3, freedBytes: 300, completed: true)
        try context.dayLog(for: date(2026, 11, 8), calendar: calendar)
            .add(kept: 5, deleted: 0, freedBytes: 0, completed: true)
        try context.dayLog(for: date(2026, 10, 31), calendar: calendar)
            .add(kept: 1, deleted: 1, freedBytes: 900, completed: true)

        let stats = try context.reviewStats(for: today, calendar: calendar)
        #expect(stats == ReviewStats(reviewedThisWeek: 6, reviewedThisMonth: 11, freedBytesThisMonth: 400))
    }

    @Test func statsAreZeroWithoutLogs() throws {
        #expect(try context.reviewStats(for: date(2026, 11, 13), calendar: calendar) == ReviewStats())
    }
}

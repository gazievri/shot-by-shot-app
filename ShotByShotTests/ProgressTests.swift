import Foundation
import SwiftData
import Testing
@testable import ShotByShot

@MainActor
struct ProgressTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }

    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// One finished portion per given date; several dates on one day are several portions.
    func progress(
        _ sessions: [Date], emptyInbox: [Date] = [], today: Date, starPerSession: Bool = false
    ) -> RitualProgress {
        var days: [Date: RitualDay] = [:]
        for date in sessions {
            let day = calendar.startOfDay(for: date)
            days[day, default: RitualDay(day: day)].completedSessions += 1
        }
        for date in emptyInbox {
            let day = calendar.startOfDay(for: date)
            days[day, default: RitualDay(day: day)].countedWithEmptyInbox = true
        }
        return RitualProgress(
            days: Array(days.values), constellation: .forMonth(of: today, calendar: calendar),
            today: today, calendar: calendar, starPerSession: starPerSession
        )
    }

    // MARK: Constellations

    @Test func everyMonthHasItsConstellation() {
        #expect(Constellation.all.map(\.month) == Array(1...12))
        #expect(Constellation.all.map(\.name) == [
            "Orion", "Carina", "Hydra", "Ursa Major", "Centaurus", "Ophiuchus",
            "Hercules", "Sagittarius", "Pisces", "Andromeda", "Perseus", "Eridanus",
        ])
        #expect(Constellation.all.map(\.stars.count) == [23, 17, 18, 20, 16, 16, 17, 25, 22, 17, 23, 27])
    }

    @Test func edgesReferToExistingStars() {
        for constellation in Constellation.all {
            for edge in constellation.edges {
                #expect(edge.count == 2)
                #expect(edge.allSatisfy { constellation.stars.indices.contains($0) })
            }
        }
    }

    @Test func constellationChangesWithTheMonth() {
        #expect(Constellation.forMonth(of: date(2026, 11, 30), calendar: calendar).name == "Perseus")
        #expect(Constellation.forMonth(of: date(2026, 12, 1), calendar: calendar).name == "Eridanus")
    }

    // MARK: Stars and windows

    @Test func starsCountDaysOfTheMonthAndWindowsDaysOfTheWeek() {
        // Friday, November 13, 2026. The week starts on Monday, November 9.
        let result = progress(
            [date(2026, 11, 2), date(2026, 11, 8), date(2026, 11, 9), date(2026, 11, 12), date(2026, 10, 31)],
            today: date(2026, 11, 13)
        )
        #expect(result.starsLit == 4)
        #expect(result.windowsLit == 2)
        #expect(result.starsTotal == 23)
        #expect(result.constellationName == "Perseus")
        #expect(!result.hasStarToday)
        #expect(!result.isConstellationComplete)
    }

    @Test func aDayGivesOneStarHoweverManySessions() {
        let result = progress(
            [date(2026, 11, 13, hour: 9), date(2026, 11, 13, hour: 21)], today: date(2026, 11, 13)
        )
        #expect(result.starsLit == 1)
        #expect(result.nightsLit == 1)
        #expect(result.windowsLit == 1)
        #expect(result.hasStarToday)
    }

    @Test func starPerSessionGivesAStarForEveryPortion() {
        let result = progress(
            [date(2026, 11, 13, hour: 9), date(2026, 11, 13, hour: 21)],
            today: date(2026, 11, 13), starPerSession: true
        )
        #expect(result.starsLit == 2)
        // Nights and windows still count days.
        #expect(result.nightsLit == 1)
        #expect(result.windowsLit == 1)
        #expect(result.hasStarToday)
    }

    @Test(arguments: [(false, 1), (true, 2)])
    func aPortionAndAnEmptyInboxOnTheSameDay(starPerSession: Bool, stars: Int) {
        let today = date(2026, 11, 13)
        let result = progress([today], emptyInbox: [today], today: today, starPerSession: starPerSession)
        #expect(result.starsLit == stars)
        #expect(result.nightsLit == 1)
        #expect(result.windowsLit == 1)
    }

    @Test func starPerSessionIgnoresOtherMonths() {
        let result = progress(
            [date(2026, 10, 31, hour: 9), date(2026, 10, 31, hour: 21), date(2026, 11, 1)],
            today: date(2026, 11, 13), starPerSession: true
        )
        #expect(result.starsLit == 1)
    }

    @Test(arguments: [false, true])
    func starsNeverExceedTheConstellationUnderEitherRule(starPerSession: Bool) {
        // Perseus has 23 stars; November has 30 days, 60 portions under the temporary rule.
        let sessions = (1...30).flatMap { [date(2026, 11, $0, hour: 9), date(2026, 11, $0, hour: 21)] }
        let result = progress(sessions, today: date(2026, 11, 30), starPerSession: starPerSession)
        #expect(result.starsLit == 23)
        #expect(result.isConstellationComplete)
        #expect(result.nightsLit == 30)
    }

    @Test func newMonthStartsWithAnEmptySky() {
        let result = progress([date(2026, 11, 29), date(2026, 11, 30)], today: date(2026, 12, 1))
        #expect(result.starsLit == 0)
        #expect(result.constellationName == "Eridanus")
        // November 30 and December 1 share a week.
        #expect(result.windowsLit == 1)
    }

    @Test func constellationIsCompleteWhenAllStarsAreLit() {
        let days = (1...23).map { date(2026, 11, $0) }
        let result = progress(days, today: date(2026, 11, 23))
        #expect(result.isConstellationComplete)
        #expect(result.starsLit == 23)
    }

    @Test func starsNeverExceedTheConstellation() {
        // June has 30 days, Ophiuchus has 16 stars.
        let days = (1...30).map { date(2026, 6, $0) }
        #expect(progress(days, today: date(2026, 6, 30)).starsLit == 16)
    }

    @Test func skippedMeansYesterdayWasMissedAfterTheRitualBegan() {
        let today = date(2026, 11, 13)
        #expect(progress([date(2026, 11, 10)], today: today).skippedYesterday)
        #expect(!progress([date(2026, 11, 12)], today: today).skippedYesterday)
        // Nothing before yesterday: the ritual has not begun, nothing was skipped.
        #expect(!progress([], today: today).skippedYesterday)
        #expect(!progress([today], today: today).skippedYesterday)
    }

    // MARK: Day logs

    @Test func onlyCompletedOrEmptyInboxDaysCountAsNights() throws {
        let context = ModelContext(ModelContainer.shotByShot(inMemory: true))
        let today = date(2026, 11, 13)

        try context.dayLog(for: date(2026, 11, 11), calendar: calendar)
            .add(kept: 1, deleted: 0, freedBytes: 0, completed: false)
        #expect(try context.progress(for: today, calendar: calendar).nightsLit == 0)
        #expect(try context.progress(for: today, calendar: calendar).starsLit == 0)

        try context.dayLog(for: date(2026, 11, 11), calendar: calendar)
            .add(kept: 2, deleted: 0, freedBytes: 0, completed: true)
        try context.dayLog(for: date(2026, 11, 11), calendar: calendar)
            .add(kept: 3, deleted: 0, freedBytes: 0, completed: true)
        #expect(try context.progress(for: today, calendar: calendar).nightsLit == 1)

        try context.countDayWithEmptyInbox(on: today, calendar: calendar)
        let result = try context.progress(for: today, calendar: calendar)
        #expect(result.nightsLit == 2)
        // Two finished portions and an empty-inbox day under the rule in force.
        #expect(result.starsLit == (RitualRules.starPerSession ? 3 : 2))
        #expect(result.hasStarToday)
    }
}

struct MoonPhaseTests {
    func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func referenceNewMoonIsDark() {
        let phase = MoonPhase(date: utc(2000, 1, 6, 18, 14))
        #expect(phase.fraction < 0.001)
        #expect(phase.illumination < 0.001)
    }

    @Test func halfASynodicMonthLaterTheMoonIsFull() {
        let phase = MoonPhase(date: MoonPhase.referenceNewMoon.addingTimeInterval(MoonPhase.synodicMonth / 2))
        #expect(abs(phase.fraction - 0.5) < 0.001)
        #expect(phase.illumination > 0.999)
    }

    // The mean synodic month drifts from the true phase by a few hours, hence the tolerances.
    @Test func knownFullMoons() {
        // December 27, 2023, 00:33 UTC and November 24, 2026, 14:53 UTC.
        #expect(MoonPhase(date: utc(2023, 12, 27, 0, 33)).illumination > 0.98)
        #expect(MoonPhase(date: utc(2026, 11, 24, 14, 53)).illumination > 0.98)
    }

    @Test func knownNewMoons() {
        // April 8, 2024, 18:21 UTC (total solar eclipse) and November 9, 2026, 07:02 UTC.
        #expect(MoonPhase(date: utc(2024, 4, 8, 18, 21)).illumination < 0.02)
        #expect(MoonPhase(date: utc(2026, 11, 9, 7, 2)).illumination < 0.02)
    }

    @Test func mockupDateIsAWaxingCrescent() {
        // The mockups show November 13, 2026: about 16 % lit, waxing.
        let phase = MoonPhase(date: utc(2026, 11, 13, 12))
        #expect(phase.isWaxing)
        #expect((0.10...0.25).contains(phase.illumination))
    }

    @Test func datesBeforeTheReferenceStayInRange() {
        let phase = MoonPhase(date: utc(1999, 12, 20))
        #expect((0..<1).contains(phase.fraction))
    }
}

import Foundation
import SwiftData

/// What the City illustration shows about the ritual on a given day.
nonisolated struct RitualProgress: Equatable, Sendable {
    /// Nights of this week. One window per day, seven at most.
    var windowsLit = 0
    /// Stars lit this month: one per night, or one per finished portion under
    /// `RitualRules.starPerSession`. Never more than the constellation has.
    var starsLit = 0
    /// Days of this month when a portion was reviewed to the end. Unlike stars, not capped.
    var nightsLit = 0
    /// Total stars in this month's constellation.
    var starsTotal = 0
    var constellationName = ""
    var hasStarToday = false
    /// Yesterday went without a star although the ritual had already begun.
    var skippedYesterday = false

    var isConstellationComplete: Bool {
        starsTotal > 0 && starsLit >= starsTotal
    }

    init(
        days: [RitualDay], constellation: Constellation, today: Date, calendar: Calendar,
        starPerSession: Bool = RitualRules.starPerSession
    ) {
        let nights = Set(days.filter(\.isNight).map { calendar.startOfDay(for: $0.day) })
        let startOfToday = calendar.startOfDay(for: today)
        windowsLit = min(7, nights.count { calendar.isDate($0, equalTo: today, toGranularity: .weekOfYear) })
        nightsLit = nights.count { calendar.isDate($0, equalTo: today, toGranularity: .month) }
        starsTotal = constellation.stars.count
        let earned = starPerSession
            ? days
                .filter { calendar.isDate($0.day, equalTo: today, toGranularity: .month) }
                .reduce(0) { $0 + $1.completedSessions + ($1.countedWithEmptyInbox ? 1 : 0) }
            : nightsLit
        // A month can bring more stars than the constellation has.
        starsLit = min(starsTotal, earned)
        constellationName = constellation.name
        hasStarToday = nights.contains(startOfToday)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) {
            skippedYesterday = !nights.contains(yesterday) && nights.contains { $0 < yesterday }
        }
    }

    init() {}
}

/// What one day contributes: the counters of its `DayLog`.
nonisolated struct RitualDay: Equatable, Sendable {
    var day: Date
    var completedSessions = 0
    var countedWithEmptyInbox = false

    /// A night is a day when a portion was reviewed to the end, or when the app
    /// was opened with an empty inbox.
    var isNight: Bool {
        completedSessions > 0 || countedWithEmptyInbox
    }
}

extension DayLog {
    var hasStar: Bool {
        completedSessions > 0 || countedWithEmptyInbox
    }
}

extension RitualProgress {
    init(logs: [DayLog], date: Date = .now, calendar: Calendar = .current) {
        self.init(
            days: logs.map {
                RitualDay(
                    day: $0.day, completedSessions: $0.completedSessions,
                    countedWithEmptyInbox: $0.countedWithEmptyInbox
                )
            },
            constellation: .forMonth(of: date, calendar: calendar),
            today: date, calendar: calendar
        )
    }
}

extension ModelContext {
    func progress(for date: Date = .now, calendar: Calendar = .current) throws -> RitualProgress {
        RitualProgress(logs: try fetch(FetchDescriptor<DayLog>()), date: date, calendar: calendar)
    }

    /// With nothing left to sort, opening the app is enough to keep the ritual going.
    func countDayWithEmptyInbox(on date: Date = .now, calendar: Calendar = .current) throws {
        try dayLog(for: date, calendar: calendar).countedWithEmptyInbox = true
    }
}

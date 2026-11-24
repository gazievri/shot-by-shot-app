import Foundation
import SwiftData

@Model
final class DayLog {
    /// Start of the day in the user's calendar.
    @Attribute(.unique) var day: Date
    var completedSessions: Int
    var reviewed: Int
    var kept: Int
    var deleted: Int
    var freedBytes: Int64
    var countedWithEmptyInbox: Bool

    init(day: Date) {
        self.day = day
        self.completedSessions = 0
        self.reviewed = 0
        self.kept = 0
        self.deleted = 0
        self.freedBytes = 0
        self.countedWithEmptyInbox = false
    }

    /// Adds the applied decisions of one session. A session closed early still
    /// counts its decisions, but not as a completed session.
    func add(kept: Int, deleted: Int, freedBytes: Int64, completed: Bool) {
        self.kept += kept
        self.deleted += deleted
        self.reviewed += kept + deleted
        self.freedBytes += freedBytes
        if completed { completedSessions += 1 }
    }
}

nonisolated struct ReviewStats: Equatable, Sendable {
    var reviewedThisWeek = 0
    var reviewedThisMonth = 0
    var freedBytesThisMonth: Int64 = 0
}

extension ModelContext {
    func dayLog(for date: Date = .now, calendar: Calendar = .current) throws -> DayLog {
        let day = calendar.startOfDay(for: date)
        var descriptor = FetchDescriptor<DayLog>(predicate: #Predicate { $0.day == day })
        descriptor.fetchLimit = 1
        if let existing = try fetch(descriptor).first { return existing }
        let log = DayLog(day: day)
        insert(log)
        return log
    }

    func reviewStats(for date: Date = .now, calendar: Calendar = .current) throws -> ReviewStats {
        var stats = ReviewStats()
        for log in try fetch(FetchDescriptor<DayLog>()) {
            if calendar.isDate(log.day, equalTo: date, toGranularity: .weekOfYear) {
                stats.reviewedThisWeek += log.reviewed
            }
            if calendar.isDate(log.day, equalTo: date, toGranularity: .month) {
                stats.reviewedThisMonth += log.reviewed
                stats.freedBytesThisMonth += log.freedBytes
            }
        }
        return stats
    }
}

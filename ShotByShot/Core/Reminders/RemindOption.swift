import Foundation

/// The quick choices of the Remind menu. Reminders are local notifications;
/// the Reminders app and EventKit are not involved.
nonisolated enum RemindOption: CaseIterable, Sendable {
    case tonight, tomorrow, weekend, nextWeek

    var title: String {
        switch self {
        case .tonight: String(localized: "Tonight")
        case .tomorrow: String(localized: "Tomorrow")
        case .weekend: String(localized: "This Weekend")
        case .nextWeek: String(localized: "Next Week")
        }
    }

    /// `nil` when the option makes no sense any more: there is no "tonight" after 8 PM.
    func date(after now: Date, calendar: Calendar = .current) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        switch self {
        case .tonight:
            guard let tonight = calendar.date(byAdding: .hour, value: 20, to: startOfToday), tonight > now else {
                return nil
            }
            return tonight
        case .tomorrow:
            return calendar.date(byAdding: DateComponents(day: 1, hour: 9), to: startOfToday)
        case .weekend:
            // The coming Saturday, 10 AM. On a Saturday afternoon that is next week's.
            return calendar.nextDate(
                after: now, matching: DateComponents(hour: 10, minute: 0, weekday: 7), matchingPolicy: .nextTime
            )
        case .nextWeek:
            return calendar.nextDate(
                after: now, matching: DateComponents(hour: 9, minute: 0, weekday: 2), matchingPolicy: .nextTime
            )
        }
    }

    /// Shown next to the title: the time for today and tomorrow, the weekday otherwise.
    func detail(for date: Date) -> String {
        switch self {
        case .tonight, .tomorrow: date.formatted(date: .omitted, time: .shortened)
        case .weekend, .nextWeek: date.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    static func available(after now: Date = .now, calendar: Calendar = .current) -> [(option: RemindOption, date: Date)] {
        allCases.compactMap { option in
            option.date(after: now, calendar: calendar).map { (option, $0) }
        }
    }
}

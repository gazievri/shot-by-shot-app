import Foundation

/// The little the widget needs, kept in the App Group. This file is compiled into both
/// the app, which writes the snapshot, and the widget, which reads it.
nonisolated struct WidgetSnapshot: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case waiting(Int)
        case done(nights: Int)
        case needsSetup
    }

    var hasAccess = false
    var portion = 0
    var isDoneToday = false
    /// Days of the month with a finished portion, as of `day`.
    var nights = 0
    /// Start of the day the snapshot was computed on.
    var day = Date.distantPast

    /// The widget may show a snapshot on a later day than it was computed: "done today"
    /// ends at midnight, and a new month starts with no nights.
    func state(at date: Date, calendar: Calendar = .current) -> State {
        guard hasAccess else { return .needsSetup }
        let isSameDay = calendar.isDate(day, inSameDayAs: date)
        if portion > 0, !(isDoneToday && isSameDay) { return .waiting(portion) }
        let isSameMonth = calendar.isDate(day, equalTo: date, toGranularity: .month)
        return .done(nights: isSameMonth ? nights : 0)
    }

    init(hasAccess: Bool = false, portion: Int = 0, isDoneToday: Bool = false, nights: Int = 0, day: Date = .distantPast) {
        self.hasAccess = hasAccess
        self.portion = portion
        self.isDoneToday = isDoneToday
        self.nights = nights
        self.day = day
    }

    init(defaults: UserDefaults) {
        hasAccess = defaults.bool(forKey: "widget.hasAccess")
        portion = defaults.integer(forKey: "widget.portion")
        isDoneToday = defaults.bool(forKey: "widget.isDoneToday")
        nights = defaults.integer(forKey: "widget.nights")
        day = defaults.object(forKey: "widget.day") as? Date ?? .distantPast
    }

    func write(to defaults: UserDefaults) {
        defaults.set(hasAccess, forKey: "widget.hasAccess")
        defaults.set(portion, forKey: "widget.portion")
        defaults.set(isDoneToday, forKey: "widget.isDoneToday")
        defaults.set(nights, forKey: "widget.nights")
        defaults.set(day, forKey: "widget.day")
    }
}

import Foundation

/// What a caption template may refer to: when the screenshot was taken, never what is on it.
nonisolated struct CaptionContext: Sendable {
    let takenAt: Date
    var now = Date.now
    /// Screenshots taken within the same minute, this one included.
    var sameMinuteCount = 1
    var calendar = Calendar.current

    var hour: Int { calendar.component(.hour, from: takenAt) }
    var weekday: Int { calendar.component(.weekday, from: takenAt) }
    var ageInYears: Int { calendar.dateComponents([.year], from: takenAt, to: now).year ?? 0 }
    var ageInDays: Int { calendar.dateComponents([.day], from: takenAt, to: now).day ?? 0 }
    var isNight: Bool { hour < 5 }
}

/// Captions used when the model is unavailable or has no guess. They tease the habit
/// of saving screenshots, their timing and their age; never people, money or health.
nonisolated enum CaptionTemplate: CaseIterable, Sendable {
    case nightNoQuestions, nightBusy, vintage, yearInTheDark, savedYearsAgo, fresh
    case mondayMorning, weekend, sameMinute, forAReason, mattered, pretend
    case nightNothingGood, olderThanApps, waitedAYear, stillWarm
    case weekendPlans, thorough, futureYou, seemedImportant

    func matches(_ context: CaptionContext) -> Bool {
        switch self {
        case .nightNoQuestions, .nightBusy, .nightNothingGood: context.isNight
        case .vintage, .olderThanApps: context.ageInYears >= 3
        case .yearInTheDark, .waitedAYear: context.ageInYears >= 1
        // From two years on, so the phrase never reads "1 years".
        case .savedYearsAgo: context.ageInYears >= 2
        case .fresh, .stillWarm: context.ageInDays < 7
        case .mondayMorning: context.weekday == 2 && (5..<12).contains(context.hour)
        case .weekend, .weekendPlans: context.weekday == 1 || context.weekday == 7
        case .sameMinute, .thorough: context.sameMinuteCount > 1
        case .forAReason, .mattered, .pretend, .futureYou, .seemedImportant: true
        }
    }

    func text(_ context: CaptionContext) -> String {
        let time = context.takenAt.formatted(date: .omitted, time: .shortened)
        return switch self {
        case .nightNoQuestions: String(localized: "Taken at \(time). No questions asked.")
        case .nightBusy: String(localized: "\(time). Past-you was busy.")
        case .vintage: String(localized: "\(context.ageInYears) years old. Practically vintage.")
        case .yearInTheDark: String(localized: "A year in the dark. Still needed?")
        case .savedYearsAgo: String(localized: "Saved \(context.ageInYears) years ago. For later, apparently.")
        case .fresh: String(localized: "Fresh one. Barely had time to forget it.")
        case .mondayMorning: String(localized: "Monday morning screenshot. Bold.")
        case .weekend: String(localized: "A weekend find.")
        case .sameMinute: String(localized: "One of \(context.sameMinuteCount) from the same minute.")
        case .forAReason: String(localized: "You saved this for a reason. Probably.")
        case .mattered: String(localized: "Past-you thought this mattered.")
        case .pretend: String(localized: "Keep, delete, or pretend you never saw it?")
        case .nightNothingGood: String(localized: "Nothing good gets screenshotted at \(time).")
        case .olderThanApps: String(localized: "Older than some of your apps.")
        case .waitedAYear: String(localized: "It waited a year. It can wait one more tap.")
        case .stillWarm: String(localized: "Still warm.")
        case .weekendPlans: String(localized: "Weekend-you had plans.")
        case .thorough: String(localized: "\(context.sameMinuteCount) in a minute. Thorough.")
        case .futureYou: String(localized: "Future-you says thanks. Or sorry.")
        case .seemedImportant: String(localized: "This seemed important at the time.")
        }
    }
}

/// Hands out templates so that none repeats until every other fitting one has been shown.
nonisolated struct CaptionRotation: Sendable {
    private(set) var shown: Set<CaptionTemplate> = []

    mutating func next(for context: CaptionContext) -> CaptionTemplate {
        let fitting = CaptionTemplate.allCases.filter { $0.matches(context) }
        var fresh = fitting.filter { !shown.contains($0) }
        if fresh.isEmpty {
            shown.subtract(fitting)
            fresh = fitting
        }
        // Five templates fit any screenshot, so there is always something to pick.
        let template = fresh.randomElement() ?? .forAReason
        shown.insert(template)
        return template
    }
}

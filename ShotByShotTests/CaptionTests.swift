import Foundation
import Testing
@testable import ShotByShot

struct CaptionTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Friday, November 13, 2026, noon.
    var now: Date { date(2026, 11, 13) }

    func context(takenAt: Date, sameMinute: Int = 1) -> CaptionContext {
        CaptionContext(takenAt: takenAt, now: now, sameMinuteCount: sameMinute, calendar: calendar)
    }

    func fitting(_ context: CaptionContext) -> Set<CaptionTemplate> {
        Set(CaptionTemplate.allCases.filter { $0.matches(context) })
    }

    @Test func fiveTemplatesFitAnyScreenshot() {
        // A Wednesday afternoon three weeks ago: nothing special about it.
        #expect(fitting(context(takenAt: date(2026, 10, 21, 15))) == [.forAReason, .mattered, .pretend, .futureYou, .seemedImportant])
    }

    @Test func nightScreenshotsGetNightTemplates() {
        let night = fitting(context(takenAt: date(2026, 10, 21, 2, 47)))
        #expect(night.isSuperset(of: [.nightNoQuestions, .nightBusy, .nightNothingGood]))
        #expect(!fitting(context(takenAt: date(2026, 10, 21, 5))).contains(.nightNoQuestions))
    }

    @Test func ageDecidesWhichAgeTemplatesFit() {
        let fresh = fitting(context(takenAt: date(2026, 11, 10)))
        #expect(fresh.contains(.fresh))
        #expect(!fresh.contains(.yearInTheDark))

        let oneYear = fitting(context(takenAt: date(2025, 10, 1)))
        #expect(oneYear.contains(.yearInTheDark))
        #expect(!oneYear.contains(.savedYearsAgo))
        #expect(!oneYear.contains(.vintage))

        let fourYears = fitting(context(takenAt: date(2022, 6, 1)))
        #expect(fourYears.isSuperset(of: [.vintage, .yearInTheDark, .savedYearsAgo]))
        #expect(!fourYears.contains(.fresh))
    }

    @Test func weekdayTemplates() {
        // November 9, 2026 is a Monday; November 7 is a Saturday.
        #expect(fitting(context(takenAt: date(2026, 11, 9, 8))).contains(.mondayMorning))
        #expect(!fitting(context(takenAt: date(2026, 11, 9, 14))).contains(.mondayMorning))
        #expect(fitting(context(takenAt: date(2026, 11, 7))).contains(.weekend))
        #expect(!fitting(context(takenAt: date(2026, 11, 9, 8))).contains(.weekend))
    }

    @Test func sameMinuteNeedsCompany() {
        #expect(fitting(context(takenAt: date(2026, 10, 21, 15), sameMinute: 3)).contains(.sameMinute))
        #expect(!fitting(context(takenAt: date(2026, 10, 21, 15))).contains(.sameMinute))
    }

    @Test func textsCarryTimeAgeAndCount() {
        let old = context(takenAt: date(2022, 6, 1, 2, 47), sameMinute: 4)
        #expect(CaptionTemplate.vintage.text(old) == "4 years old. Practically vintage.")
        #expect(CaptionTemplate.savedYearsAgo.text(old) == "Saved 4 years ago. For later, apparently.")
        #expect(CaptionTemplate.sameMinute.text(old) == "One of 4 from the same minute.")
        #expect(CaptionTemplate.nightNoQuestions.text(old).hasSuffix("No questions asked."))
    }

    @Test func noTemplateRepeatsUntilAllFittingOnesWereShown() {
        let plain = context(takenAt: date(2026, 10, 21, 15))
        var rotation = CaptionRotation()
        let firstRound = (0..<5).map { _ in rotation.next(for: plain) }
        #expect(Set(firstRound) == [.forAReason, .mattered, .pretend, .futureYou, .seemedImportant])

        // Everything fitting has been shown: the rotation starts over.
        let secondRound = (0..<5).map { _ in rotation.next(for: plain) }
        #expect(Set(secondRound) == [.forAReason, .mattered, .pretend, .futureYou, .seemedImportant])
    }

    @Test func theSetHasAtLeastTwentyTemplates() {
        #expect(CaptionTemplate.allCases.count >= 20)
    }

    @Test func rotationOnlyOffersFittingTemplates() {
        var rotation = CaptionRotation()
        let night = context(takenAt: date(2026, 10, 21, 2))
        for _ in 0..<20 {
            #expect(rotation.next(for: night).matches(night))
        }
    }

    @Test func guessMustBeAShortQuestion() {
        #expect(ScreenshotInsight.sanitizedGuess(" Planning a haircut? ") == "Planning a haircut?")
        #expect(ScreenshotInsight.sanitizedGuess("You want this desk.") == nil)
        #expect(ScreenshotInsight.sanitizedGuess("Is this one of those things you really wanted to buy?") == nil)
        #expect(ScreenshotInsight.sanitizedGuess("") == nil)
        #expect(ScreenshotInsight.sanitizedGuess(nil) == nil)
    }
}

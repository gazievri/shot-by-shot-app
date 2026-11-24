import Foundation
import Testing
@testable import ShotByShot

struct LibraryGroupTests {
    func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: offset)
    }

    @Test func countsScreenshotsPerCategoryAndSkipsEmptyOnes() {
        let groups = LibraryGroup.groups(from: [
            (.buy, date(1)), (.buy, date(2)), (.read, date(3)),
        ])
        #expect(Set(groups) == [LibraryGroup(category: .buy, count: 2), LibraryGroup(category: .read, count: 1)])
    }

    @Test func mostRecentlyUsedCategoryComesFirst() {
        let groups = LibraryGroup.groups(from: [
            (.buy, date(10)), (.read, date(30)), (.cook, date(20)), (.buy, date(40)),
        ])
        #expect(groups.map(\.category) == [.buy, .read, .cook])
    }

    @Test func privateIsAlwaysLast() {
        let groups = LibraryGroup.groups(from: [
            (.private, date(100)), (.buy, date(1)), (.read, date(2)),
        ])
        #expect(groups.map(\.category) == [.read, .buy, .private])
    }

    @Test func noScreenshotsGiveNoGroups() {
        #expect(LibraryGroup.groups(from: []).isEmpty)
    }

    @Test func rowTitleIsTheFirstLineWithText() {
        #expect(ScreenshotItem.title(fromRecognizedText: "\n   \n  Gate B12  \nBoarding 14:05") == "Gate B12")
        #expect(ScreenshotItem.title(fromRecognizedText: "") == nil)
        #expect(ScreenshotItem.title(fromRecognizedText: " \n\t\n") == nil)
        #expect(ScreenshotItem.title(fromRecognizedText: String(repeating: "a", count: 500))?.count == 200)
    }
}

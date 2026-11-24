import Foundation
import Testing
@testable import ShotByShot

struct ContextActionTests {
    /// Friday, November 13, 2026, noon UTC.
    let now = Date(timeIntervalSince1970: 1_794_571_200 + 12 * 3_600)

    @Test func findsOneActionOfEachKindInPriorityOrder() {
        let text = """
        Call us at +1 (415) 555-0132
        https://example.com/tickets
        1 Infinite Loop, Cupertino, CA 95014
        Concert on December 24, 2026 at 7:00 PM
        See also https://example.com/second
        """
        let actions = ContextAction.detect(in: text, now: now)
        #expect(actions.map(\.title) == ["Add to Calendar", "Open in Maps", "Open Link", "Call"])
        #expect(actions.contains(.link(URL(string: "https://example.com/tickets")!)))
    }

    @Test func statusBarClockIsNotAnEvent() {
        #expect(ContextAction.detect(in: "9:41\nInbox\nReview 3", now: now).isEmpty)
    }

    @Test func pastDatesAreNotOffered() {
        let actions = ContextAction.detect(in: "Meeting on March 3, 2020 at 10:00 AM", now: now)
        #expect(!actions.contains { if case .calendar = $0 { true } else { false } })
    }

    @Test func plainTextHasNoActions() {
        #expect(ContextAction.detect(in: "You saved this for a reason. Probably.", now: now).isEmpty)
    }

    @Test func actionsOpenTheRightURLs() {
        #expect(ContextAction.call("+1 (415) 555-0132").url == URL(string: "tel:+14155550132"))
        #expect(ContextAction.maps("1 Infinite Loop, Cupertino").url?.host() == "maps.apple.com")
        #expect(ContextAction.calendar(now).url == nil)
    }
}

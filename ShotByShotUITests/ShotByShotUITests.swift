import XCTest

final class ShotByShotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingAndTabNavigation() {
        let app = launchSampleLibrary()
        tap(app.buttons["Later"])
        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Review 3"].exists)

        tap(app.tabBars.buttons["Library"])
        XCTAssertTrue(app.staticTexts["Nothing saved yet"].waitForExistence(timeout: 5))
        tap(app.buttons["Review screenshots"])
        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDeleteCanBeUndoneBeforeFinishing() {
        let app = launchSampleLibrary()
        tap(app.buttons["Later"])
        tap(app.buttons["Review 3"])
        XCTAssertTrue(app.navigationBars["1 of 3"].waitForExistence(timeout: 5))
        tap(app.buttons["Delete"])
        XCTAssertTrue(app.navigationBars["2 of 3"].waitForExistence(timeout: 5))
        tap(app.buttons["Undo"])
        XCTAssertTrue(app.navigationBars["1 of 3"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Undo"].isEnabled)
    }

    @MainActor
    func testFirstPortionSummaryAndSavedCategory() {
        let app = launchSampleLibrary()
        tap(app.buttons["Review 3 now"])
        XCTAssertTrue(app.navigationBars["1 of 3"].waitForExistence(timeout: 5))
        tap(app.buttons["Choose category"])
        tap(app.buttons["Read"])
        for index in 2...3 {
            XCTAssertTrue(app.navigationBars["\(index) of 3"].waitForExistence(timeout: 5))
            tap(app.buttons["Delete"])
        }

        XCTAssertTrue(app.staticTexts["3 done today"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Review 3 More"].exists)
        tap(app.buttons["Done"])
        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(identifier: "Screenshot").element(boundBy: 6).exists)
        XCTAssertFalse(app.buttons.matching(identifier: "Screenshot").element(boundBy: 7).exists)

        tap(app.tabBars.buttons["Library"])
        tap(app.buttons["Read"])
        XCTAssertTrue(app.navigationBars["Read"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Nothing saved yet"].exists)
    }

    @MainActor
    func testOnboardingAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleLibrary", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        try audit(app, acceptedContrast: ["Your screenshots never leave your iPhone\\."])
    }

    @MainActor
    func testInboxAccessibilityAudit() throws {
        let app = launchSampleLibrary()
        tap(app.buttons["Later"])
        XCTAssertTrue(app.buttons["Review 3"].waitForExistence(timeout: 5))
        try audit(app)
    }

    @MainActor
    func testLibraryAccessibilityAudit() throws {
        let app = launchSampleLibrary()
        tap(app.buttons["Later"])
        tap(app.tabBars.buttons["Library"])
        XCTAssertTrue(app.staticTexts["Nothing saved yet"].waitForExistence(timeout: 5))
        try audit(app)
    }

    @MainActor
    func testSessionAccessibilityAudit() throws {
        let app = launchSampleLibrary()
        tap(app.buttons["Review 3 now"])
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        // The date label depends on the day the test runs, so match its shape.
        try audit(app, acceptedContrast: ["Delete", ".*\\d{4} at \\d{1,2}:\\d{2}.*"])
    }

    @MainActor
    func testSummaryAccessibilityAudit() throws {
        let app = launchSampleLibrary()
        tap(app.buttons["Review 3 now"])
        for index in 1...3 {
            XCTAssertTrue(app.navigationBars["\(index) of 3"].waitForExistence(timeout: 5))
            tap(app.buttons["Delete"])
        }
        XCTAssertTrue(app.staticTexts["3 done today"].waitForExistence(timeout: 10))
        try audit(app, acceptedContrast: ["A new star tonight\\. .*", "Get 3 screenshots every evening at .*"])
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // The audit stops at its first issue unless a handler takes each one, so collect them all
    // and fail once with the full list for the screen.
    // `acceptedContrast` holds label patterns of system-colored elements (`.secondary` text,
    // the destructive button) whose contrast UI spec section 7.6 accepts as is. Only those
    // elements are skipped, so the contrast check still covers the app's own colors.
    @MainActor
    private func audit(
        _ app: XCUIApplication,
        acceptedContrast: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        var issues: [String] = []
        // The audit sometimes reports an issue without its element, and an accepted one can't be
        // told apart then, so run it again a couple of times before giving up.
        for _ in 1...3 {
            issues = []
            var hasUnidentifiedIssue = false
            try app.performAccessibilityAudit { issue in
                if issue.auditType == .contrast, let label = issue.element?.label,
                   acceptedContrast.contains(where: { label.range(of: "^\($0)$", options: .regularExpression) != nil }) {
                    return true
                }
                hasUnidentifiedIssue = hasUnidentifiedIssue || issue.element == nil
                let element = issue.element?.description ?? "no element reported"
                issues.append("\(issue.compactDescription): \(element)")
                return true
            }
            if !hasUnidentifiedIssue { break }
        }
        XCTAssertTrue(
            issues.isEmpty,
            "\(issues.count) accessibility issues:\n" + issues.joined(separator: "\n"),
            file: file,
            line: line
        )
    }

    @MainActor
    private func launchSampleLibrary() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleLibrary", "-sampleStandardScreenshots", "-AppleLanguages", "(en)"]
        app.launch()
        tap(app.buttons["Continue"])
        return app
    }

    @MainActor
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 5) else {
            XCTFail("Element did not appear: \(element)", file: file, line: line)
            return
        }
        element.tap()
    }
}

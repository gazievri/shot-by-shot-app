import XCTest

final class WorkflowRegressionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testClosePartialPortionKeepsOnlyDecidedScreenshot() {
        let app = launch()
        tap(app.buttons["Review 3"])
        keepInRead(app)
        XCTAssertTrue(app.navigationBars["2 of 3"].waitForExistence(timeout: 5))
        tap(app.buttons["Close"])
        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "Screenshot").count, 9)

        tap(app.tabBars.buttons["Library"])
        tap(app.buttons["Read"])
        XCTAssertTrue(app.staticTexts["Screenshot"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReviewMorePreservesDailyTotals() {
        let app = launch()
        tap(app.buttons["Review 3"])
        deletePortion(app)
        XCTAssertTrue(app.staticTexts["3 done today"].waitForExistence(timeout: 10))

        tap(app.buttons["Review 3 More"])
        deletePortion(app)
        XCTAssertTrue(app.staticTexts["6 done today"].waitForExistence(timeout: 10))
        tap(app.buttons["Done"])
        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "Screenshot").count, 4)
    }

    @MainActor
    func testUndoKeepRemovesLibraryRecord() {
        let app = launch()
        tap(app.buttons["Review 3"])
        keepInRead(app)
        XCTAssertTrue(app.navigationBars["2 of 3"].waitForExistence(timeout: 5))
        tap(app.buttons["Undo"])
        XCTAssertTrue(app.navigationBars["1 of 3"].waitForExistence(timeout: 5))
        tap(app.buttons["Close"])

        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "Screenshot").count, 10)
        tap(app.tabBars.buttons["Library"])
        XCTAssertTrue(app.staticTexts["Nothing saved yet"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleLibrary", "-sampleStandardScreenshots", "-AppleLanguages", "(en)"]
        app.launch()
        tap(app.buttons["Continue"])
        tap(app.buttons["Later"])
        return app
    }

    @MainActor
    private func keepInRead(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["1 of 3"].waitForExistence(timeout: 5))
        tap(app.buttons["Choose category"])
        tap(app.buttons["Read"])
    }

    @MainActor
    private func deletePortion(_ app: XCUIApplication) {
        for index in 1...3 {
            XCTAssertTrue(app.navigationBars["\(index) of 3"].waitForExistence(timeout: 5))
            tap(app.buttons["Delete"])
        }
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

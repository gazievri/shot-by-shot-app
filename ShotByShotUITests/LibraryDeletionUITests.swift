import XCTest

/// Removing a kept screenshot from its own screen (D1): the screen closes first and the
/// record goes after it, and the last screenshot of a category leads back to Library.
final class LibraryDeletionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDeletingAndRemovingFromTheScreenshotScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-sampleLibrary", "-sampleStandardScreenshots", "-AppleLanguages", "(en)"]
        app.launch()
        tap(app.buttons["Continue"])
        tap(app.buttons["Review 3 now"])
        for index in 1...3 {
            XCTAssertTrue(app.navigationBars["\(index) of 3"].waitForExistence(timeout: 5))
            tap(app.buttons["Choose category"])
            tap(app.buttons["Read"])
        }
        XCTAssertTrue(app.staticTexts["3 done today"].waitForExistence(timeout: 10))
        tap(app.buttons["Done"])
        tap(app.tabBars.buttons["Library"])
        tap(app.buttons["Read"])
        XCTAssertTrue(app.navigationBars["Read"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.cells.count, 3)

        // Delete with other screenshots left: back to the category.
        tap(app.cells.firstMatch)
        tap(deleteButton(in: app))
        XCTAssertTrue(app.navigationBars["Read"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForCellCount(2, in: app))

        // Remove from Library closes the screen as well.
        tap(app.cells.firstMatch)
        tap(app.buttons["More"])
        tap(app.buttons["Remove from Library"])
        XCTAssertTrue(app.navigationBars["Read"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForCellCount(1, in: app))

        // The last screenshot of the category: back to Library, the category is gone.
        tap(app.cells.firstMatch)
        tap(deleteButton(in: app))
        XCTAssertTrue(app.staticTexts["Nothing saved yet"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Read"].exists)
    }

    /// On iOS 26 the buttons of the bottom bar are not reported inside a toolbar element.
    @MainActor
    private func deleteButton(in app: XCUIApplication) -> XCUIElement {
        let inToolbar = app.toolbars.buttons["Delete"]
        return inToolbar.waitForExistence(timeout: 2) ? inToolbar : app.buttons["Delete"]
    }

    @MainActor
    private func waitForCellCount(_ count: Int, in app: XCUIApplication) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == %d", count), object: app.cells
        )
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
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

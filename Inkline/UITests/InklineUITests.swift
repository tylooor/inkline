import XCTest

final class InklineUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestInMemory"]
        app.launch()
    }

    private func create(_ item: String) {
        app.buttons["library-new"].tap()
        app.buttons[item].tap()
        XCTAssertTrue(app.otherElements["ink-canvas"].waitForExistence(timeout: 5) || app.scrollViews["ink-canvas"].waitForExistence(timeout: 5))
    }

    private var canvas: XCUIElement {
        let scroll = app.scrollViews["ink-canvas"]
        return scroll.exists ? scroll : app.otherElements["ink-canvas"]
    }

    private func scribble() {
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.3))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.4))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func testNotebookDrawUndoAndReturnToLibrary() {
        create("New notebook")
        let undo = app.buttons["tool-undo"]
        XCTAssertFalse(undo.isEnabled)
        scribble()
        XCTAssertTrue(undo.waitForEnabled(timeout: 3), "drawing should be undoable")
        undo.tap()
        XCTAssertTrue(app.buttons["tool-redo"].waitForEnabled(timeout: 3))
        app.buttons["nav-back"].tap()
        XCTAssertTrue(app.buttons["doc-Untitled notebook"].waitForExistence(timeout: 5))
    }

    func testToolOptionsAreTwoTapsAway() {
        create("New notebook")
        app.buttons["tool-marker"].tap()
        XCTAssertTrue(app.buttons["tool-marker"].isSelected)
        app.buttons["tool-marker"].tap()
        XCTAssertTrue(app.buttons["color-1"].waitForExistence(timeout: 3))
        app.buttons["color-1"].tap()
        XCTAssertFalse(app.buttons["color-1"].exists)
    }

    func testThemeSwitchFromNavMenu() {
        create("New notebook")
        app.buttons["nav-menu"].tap()
        app.buttons["Dark"].tap()
        app.buttons["nav-menu"].tap()
        XCTAssertTrue(app.buttons["Dark"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Dark"].label.contains("Dark"))
    }

    func testInkBarSnapsToSideEdge() {
        create("New whiteboard")
        let pen = app.buttons["tool-pen"]
        let marker = app.buttons["tool-marker"]
        XCTAssertGreaterThan(abs(marker.frame.midX - pen.frame.midX), 30, "bar starts horizontal")
        let grip = app.otherElements["ink-bar-grip"].exists ? app.otherElements["ink-bar-grip"] : app.images["ink-bar-grip"]
        let target = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5))
        grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: target)
        let vertical = NSPredicate { _, _ in
            abs(pen.frame.midX - marker.frame.midX) < 8 && abs(marker.frame.midY - pen.frame.midY) > 30
        }
        expectation(for: vertical, evaluatedWith: nil)
        waitForExpectations(timeout: 3)
    }

    func testNotebookPageBecomesWhiteboardCard() {
        create("New notebook")
        scribble()
        app.buttons["tool-insert"].tap()
        app.buttons["Send page to whiteboard…"].tap()
        app.buttons["board-new"].tap()
        XCTAssertTrue(app.buttons["Untitled whiteboard"].waitForExistence(timeout: 5), "should open the new whiteboard")
        app.buttons["nav-back"].tap()
        app.buttons["nav-back"].tap()
        XCTAssertTrue(app.staticTexts["Whiteboard · Digital · 1 card"].waitForExistence(timeout: 5), "whiteboard should hold the page card")
    }
}

private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout)
        return result == .completed
    }
}

import XCTest

final class PencilCaptureUITests: XCTestCase {
    func testDragRecordsStrokeSamples() throws {
        let app = XCUIApplication()
        app.launch()

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6))
        start.press(forDuration: 0.2, thenDragTo: end)

        // Status pill should report a finished stroke with samples.
        let label = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "strokes")
        ).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertFalse(label.label.hasPrefix("0 strokes"), "Expected recorded stroke, got: \(label.label)")
    }

    func testExportButtonExists() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Export"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Clear"].exists)
    }
}

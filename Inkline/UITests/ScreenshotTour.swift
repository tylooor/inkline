import XCTest

/// Opt-in visual tour over the capture-seeded library. Runs only when
/// TEST_RUNNER_INKLINE_SCREENSHOT_DIR and TEST_RUNNER_INKLINE_SEED_FIXTURE are set.
final class ScreenshotTour: XCTestCase {
    func testTour() throws {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["INKLINE_SCREENSHOT_DIR"], let fixture = env["INKLINE_SEED_FIXTURE"] else {
            throw XCTSkip("Screenshot tour not requested")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestInMemory"]
        app.launchEnvironment["INKLINE_SEED_FIXTURE"] = fixture
        app.launch()

        func shot(_ name: String) {
            sleep(1)
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }

        XCTAssertTrue(app.buttons["doc-Pencil capture"].waitForExistence(timeout: 10))
        shot("01-library")

        app.buttons["doc-Pencil capture"].tap()
        XCTAssertTrue(app.buttons["tool-pen"].waitForExistence(timeout: 5))
        shot("02-notebook-paper")

        app.buttons["tool-pen"].tap()
        XCTAssertTrue(app.buttons["color-0"].waitForExistence(timeout: 3))
        shot("03-pen-options")
        app.buttons["color-1"].tap()

        app.buttons["nav-menu"].tap()
        shot("04-nav-menu")
        app.buttons["Dark"].tap()
        shot("05-notebook-dark")

        let grip = app.descendants(matching: .any)["ink-bar-grip"]
        grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.45)))
        shot("06-bar-on-side")

        app.buttons["nav-back"].tap()
        XCTAssertTrue(app.buttons["doc-Capture board"].waitForExistence(timeout: 5))
        app.buttons["doc-Capture board"].tap()
        XCTAssertTrue(app.buttons["tool-pen"].waitForExistence(timeout: 5))
        shot("07-whiteboard")
    }
}

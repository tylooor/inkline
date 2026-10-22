import XCTest
@testable import Inkline

final class SurfaceLayoutTests: XCTestCase {
    func testNotebookStacksPagesWithGaps() {
        let layout = SurfaceLayout.notebook(pageSize: CGSize(width: 600, height: 800), pageCount: 3)
        XCTAssertEqual(layout.pageRect(0).minY, SurfaceLayout.margin)
        XCTAssertEqual(layout.pageRect(1).minY, layout.pageRect(0).maxY + SurfaceLayout.pageGap)
        XCTAssertEqual(layout.contentSize.height, layout.pageRect(2).maxY + SurfaceLayout.margin)
        XCTAssertEqual(layout.contentSize.width, 600 + 2 * SurfaceLayout.margin)
    }

    func testPageIndexClampsAndOwnsTrailingGap() {
        let layout = SurfaceLayout.notebook(pageSize: CGSize(width: 600, height: 800), pageCount: 3)
        XCTAssertEqual(layout.pageIndex(containing: -100), 0)
        XCTAssertEqual(layout.pageIndex(containing: layout.pageRect(1).midY), 1)
        XCTAssertEqual(layout.pageIndex(containing: layout.pageRect(0).maxY + 10), 0)
        XCTAssertEqual(layout.pageIndex(containing: 1_000_000), 2)
    }

    func testPagesNeededKeepsOneBlankPageAtTheEnd() {
        let layout = SurfaceLayout.notebook(pageSize: CGSize(width: 600, height: 800), pageCount: 3)
        XCTAssertEqual(layout.pagesNeeded(forInk: .null), 3)
        XCTAssertEqual(layout.pagesNeeded(forInk: layout.pageRect(0).insetBy(dx: 100, dy: 100)), 3)
        XCTAssertEqual(layout.pagesNeeded(forInk: layout.pageRect(2).insetBy(dx: 100, dy: 100)), 4)
    }

    func testWhiteboardIsLargeAndCentered() {
        let layout = SurfaceLayout.whiteboard
        XCTAssertGreaterThanOrEqual(layout.contentSize.width, 20_000)
        XCTAssertEqual(layout.whiteboardCenter.x, layout.contentSize.width / 2)
        XCTAssertTrue(layout.pageRects.isEmpty)
    }
}

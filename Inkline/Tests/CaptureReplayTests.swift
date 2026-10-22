import XCTest
import PencilKit
@testable import Inkline

/// Replays every bundled PencilCapture fixture (Tests/Fixtures/*.json) through Inkline's
/// ink pipeline. New captures dropped into that folder are picked up automatically.
final class CaptureReplayTests: XCTestCase {
    private struct Fixture {
        let name: String
        let session: CaptureSession
        let strokes: [ReplayStroke]
    }

    private static let fixtures: [Fixture] = {
        let urls = Bundle(for: CaptureReplayTests.self).urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { url in
            guard let session = try? CaptureReplay.load(url) else { return nil }
            return Fixture(name: url.lastPathComponent, session: session, strokes: CaptureReplay.strokes(from: session))
        }
    }()

    private func eachFixture(_ body: (Fixture) throws -> Void) rethrows {
        XCTAssertFalse(Self.fixtures.isEmpty, "No capture fixtures bundled")
        for fixture in Self.fixtures { try body(fixture) }
    }

    func testFixturesDecode() {
        eachFixture { f in
            XCTAssertFalse(f.session.strokes.isEmpty, f.name)
            XCTAssertGreaterThan(f.session.viewWidth, 0, f.name)
            XCTAssertFalse(f.strokes.isEmpty, "\(f.name): no pencil strokes survived replay")
        }
    }

    func testOnlyCompletedPencilStrokesBecomeInk() {
        eachFixture { f in
            let expected = f.session.strokes.filter { $0.tool == "pencil" && $0.samples.last?.phase == "ended" }
            XCTAssertEqual(f.strokes.map(\.id), expected.map(\.id), f.name)
            let fingerIDs = Set(f.session.strokes.filter { $0.tool != "pencil" }.map(\.id))
            XCTAssertTrue(fingerIDs.isDisjoint(with: f.strokes.map(\.id)), "\(f.name): finger touch produced ink")
        }
    }

    func testPredictedSamplesDroppedAndEstimatesFinalized() {
        eachFixture { f in
            for (raw, replay) in zip(f.session.strokes.filter { r in f.strokes.contains { $0.id == r.id } }, f.strokes) {
                let committed = raw.samples.filter { !$0.predicted && $0.phase != "estimated-update" }
                XCTAssertEqual(replay.points.count, committed.count, "\(f.name) stroke \(raw.id)")
            }
            let updates = f.session.strokes.flatMap(\.samples).filter { $0.phase == "estimated-update" }
            guard !updates.isEmpty else { return }
            let finalForces = Dictionary(updates.compactMap { u in u.estimationUpdateIndex.map { ($0, u.force) } }, uniquingKeysWith: { _, last in last })
            var changed = 0
            for raw in f.session.strokes where raw.tool == "pencil" {
                for s in raw.samples where !s.predicted && s.phase != "estimated-update" {
                    if let i = s.estimationUpdateIndex, let final = finalForces[i], final != s.force { changed += 1 }
                }
            }
            XCTAssertGreaterThan(changed, 0, "\(f.name): estimated-property updates were never applied")
        }
    }

    func testTimelineIsMonotonicPerStroke() {
        eachFixture { f in
            for stroke in f.strokes {
                let times = stroke.points.map(\.time)
                XCTAssertEqual(times, times.sorted(), "\(f.name) stroke \(stroke.id)")
            }
        }
    }

    /// Protocol captures must actually exercise the full pressure range and real tilt.
    func testProtocolCaptureCoversPressureAndTilt() {
        eachFixture { f in
            guard f.name.contains("protocol") else { return }
            let points = f.strokes.flatMap(\.points)
            let pressures = points.map(\.normalizedForce)
            let altitudes = points.map(\.altitude)
            XCTAssertGreaterThanOrEqual(pressures.max() ?? 0, 0.9, "\(f.name): pressure ramp never reached the ceiling")
            XCTAssertLessThanOrEqual(pressures.filter { $0 > 0 }.min() ?? 1, 0.1, "\(f.name): no light-pressure ink")
            XCTAssertGreaterThan((altitudes.max() ?? 0) - (altitudes.min() ?? 0), 0.5, "\(f.name): no tilt variation")
        }
    }

    func testWidthCurveIsMonotonic() {
        let forces = stride(from: 0.0, through: 4.2, by: 0.1).map { CGFloat($0) }
        let widths = forces.map { CaptureReplay.width(base: 3, force: $0) }
        XCTAssertEqual(widths, widths.sorted())
        XCTAssertEqual(CaptureReplay.width(base: 3, force: 1), 3, accuracy: 0.0001)
    }

    func testReplayedInkStaysInsideCaptureView() {
        eachFixture { f in
            let view = CGRect(x: 0, y: 0, width: f.session.viewWidth, height: f.session.viewHeight)
            let bounds = CaptureReplay.bounds(of: f.strokes)
            XCTAssertTrue(view.insetBy(dx: -4, dy: -4).contains(bounds), "\(f.name): \(bounds) outside \(view)")
        }
    }

    func testDrawingRoundTripsThroughStorage() throws {
        try eachFixture { f in
            let drawing = CaptureReplay.drawing(from: f.strokes, ink: PKInk(.pen, color: .black), baseWidth: 2.2)
            let restored = try PKDrawing(data: drawing.dataRepresentation())
            XCTAssertEqual(restored.strokes.count, f.strokes.count, f.name)
            XCTAssertEqual(restored.strokes.map { $0.path.count }, drawing.strokes.map { $0.path.count }, f.name)
            XCTAssertEqual(restored.bounds.width, drawing.bounds.width, accuracy: 0.5, f.name)
            XCTAssertEqual(restored.bounds.height, drawing.bounds.height, accuracy: 0.5, f.name)
        }
    }

    func testNotebookAppendsBlankPageWhenInkReachesLastPage() {
        eachFixture { f in
            let layout = SurfaceLayout.notebook(pageSize: PageSize.a4.points, pageCount: 1)
            let source = CaptureReplay.bounds(of: f.strokes)
            let fit = CaptureReplay.fitting(source, into: layout.pageRect(0).insetBy(dx: 40, dy: 90))
            let drawing = CaptureReplay.drawing(from: f.strokes, ink: PKInk(.pen, color: .black), baseWidth: 2.2, transform: fit)
            XCTAssertTrue(layout.pageRect(0).insetBy(dx: -8, dy: -8).contains(drawing.bounds), f.name)
            XCTAssertEqual(layout.pagesNeeded(forInk: drawing.bounds), 2, f.name)
        }
    }

    func testRenderedPagesShowTheInk() {
        eachFixture { f in
            for theme in ThemeID.allCases {
                let doc = InkDocument(title: "replay", kind: .notebook, theme: theme)
                let page = doc.layout.pageRect(0)
                let fit = CaptureReplay.fitting(CaptureReplay.bounds(of: f.strokes), into: page.insetBy(dx: 40, dy: 90))
                let drawing = CaptureReplay.drawing(from: f.strokes, ink: PKInk(.pen, color: InkPalette.colors[0]), baseWidth: 2.2, transform: fit)
                let inked = Renderer.image(of: page, layout: doc.layout, theme: .of(theme), drawing: drawing, scale: 1)
                let blank = Renderer.image(of: page, layout: doc.layout, theme: .of(theme), drawing: PKDrawing(), scale: 1)
                let changed = PixelDiff.changedFraction(inked, blank)
                XCTAssertGreaterThan(changed, 0.01, "\(f.name) on \(theme): ink barely visible (\(changed))")
                XCTAssertLessThan(changed, 0.5, "\(f.name) on \(theme): ink floods the page (\(changed))")
            }
        }
    }

    func testReplayBuildPerformance() {
        guard let fixture = Self.fixtures.first else { return XCTFail("No capture fixtures bundled") }
        measure {
            _ = CaptureReplay.drawing(from: CaptureReplay.strokes(from: fixture.session), ink: PKInk(.pen, color: .black), baseWidth: 2.2)
        }
    }
}

enum PixelDiff {
    static func changedFraction(_ a: UIImage, _ b: UIImage, threshold: Int = 40) -> Double {
        guard let pa = rgba(a), let pb = rgba(b), pa.count == pb.count else { return 1 }
        var changed = 0
        for i in stride(from: 0, to: pa.count, by: 4) {
            let d = max(abs(Int(pa[i]) - Int(pb[i])), abs(Int(pa[i + 1]) - Int(pb[i + 1])), abs(Int(pa[i + 2]) - Int(pb[i + 2])))
            if d > threshold { changed += 1 }
        }
        return Double(changed) / Double(pa.count / 4)
    }

    private static func rgba(_ image: UIImage) -> [UInt8]? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width
        let h = cg.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }
}

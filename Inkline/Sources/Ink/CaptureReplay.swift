import Foundation
import PencilKit

/// Mirror of the PencilCapture export schema (see PencilCapture/README.md).
struct CaptureSession: Codable {
    let device: String
    let osVersion: String
    let viewWidth: Double
    let viewHeight: Double
    let scale: Double
    let startedAt: String
    let strokes: [CapturedStroke]
}

struct CapturedStroke: Codable {
    let id: Int
    let tool: String
    let samples: [CaptureSample]
}

struct CaptureSample: Codable {
    var t: Double
    var x: Double
    var y: Double
    var px: Double
    var py: Double
    var force: Double
    var maxForce: Double
    var altitude: Double
    var azimuth: Double
    var type: String
    var phase: String
    var estimationUpdateIndex: Int?
    var predicted: Bool
}

struct InkPoint: Equatable {
    var location: CGPoint
    var time: TimeInterval
    /// Raw UITouch force (1.0 = average touch).
    var force: CGFloat
    /// force / maximumPossibleForce, 0...1.
    var normalizedForce: CGFloat
    var altitude: CGFloat
    var azimuth: CGFloat
}

struct ReplayStroke {
    let id: Int
    let points: [InkPoint]
}

/// Turns a raw Pencil capture into the ink the canvas would commit, so real device input
/// can drive tests and demo content.
enum CaptureReplay {
    static func load(_ url: URL) throws -> CaptureSession {
        try JSONDecoder().decode(CaptureSession.self, from: Data(contentsOf: url))
    }

    /// Pencil-only (finger pans, it never inks), cancelled touches dropped, predicted samples
    /// dropped, and estimated force/tilt/location replaced by their finalized updates.
    static func strokes(from session: CaptureSession) -> [ReplayStroke] {
        session.strokes.compactMap { stroke in
            guard stroke.tool == "pencil", stroke.samples.last?.phase == "ended" else { return nil }

            var finals: [Int: CaptureSample] = [:]
            for sample in stroke.samples where sample.phase == "estimated-update" {
                if let index = sample.estimationUpdateIndex, index >= 0 { finals[index] = sample }
            }

            let points = stroke.samples
                .filter { !$0.predicted && $0.phase != "estimated-update" }
                .map { raw -> InkPoint in
                    var s = raw
                    if let index = s.estimationUpdateIndex, index >= 0, let final = finals[index] {
                        s.force = final.force
                        s.altitude = final.altitude
                        s.azimuth = final.azimuth
                        s.px = final.px
                        s.py = final.py
                    }
                    let normalized = s.maxForce > 0 ? s.force / s.maxForce : 0
                    return InkPoint(
                        location: CGPoint(x: s.px, y: s.py),
                        time: s.t,
                        force: CGFloat(s.force),
                        normalizedForce: CGFloat(min(max(normalized, 0), 1)),
                        altitude: CGFloat(s.altitude),
                        azimuth: CGFloat(s.azimuth)
                    )
                }
            return points.isEmpty ? nil : ReplayStroke(id: stroke.id, points: points)
        }
    }

    /// Pressure response for replayed strokes: average touch (force 1) draws at `base`.
    static func width(base: CGFloat, force: CGFloat) -> CGFloat {
        base * (0.45 + 0.55 * pow(max(force, 0), 0.7))
    }

    static func drawing(
        from strokes: [ReplayStroke],
        ink: PKInk,
        baseWidth: CGFloat,
        transform: CGAffineTransform = .identity
    ) -> PKDrawing {
        let pkStrokes = strokes.map { stroke -> PKStroke in
            let start = stroke.points[0].time
            let points = stroke.points.map { p -> PKStrokePoint in
                let w = width(base: baseWidth, force: p.force)
                return PKStrokePoint(
                    location: p.location,
                    timeOffset: p.time - start,
                    size: CGSize(width: w, height: w),
                    opacity: 1,
                    force: p.force,
                    azimuth: p.azimuth,
                    altitude: p.altitude
                )
            }
            return PKStroke(
                ink: ink,
                path: PKStrokePath(controlPoints: points, creationDate: Date()),
                transform: transform
            )
        }
        return PKDrawing(strokes: pkStrokes)
    }

    static func bounds(of strokes: [ReplayStroke]) -> CGRect {
        strokes.reduce(CGRect.null) { rect, stroke in
            stroke.points.reduce(rect) { $0.union(CGRect(origin: $1.location, size: .zero)) }
        }
    }

    /// Scales `source` to fit `target`, centered horizontally and top-aligned.
    static func fitting(_ source: CGRect, into target: CGRect) -> CGAffineTransform {
        let s = min(target.width / max(source.width, 1), target.height / max(source.height, 1))
        return CGAffineTransform(
            a: s, b: 0, c: 0, d: s,
            tx: target.midX - source.midX * s,
            ty: target.minY - source.minY * s
        )
    }
}

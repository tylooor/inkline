import UIKit

/// One raw input sample, faithful to UITouch — the unit tests for the real
/// app will replay these.
struct TouchSample: Codable {
    /// Seconds since session start.
    var t: Double
    /// Raw locationInView, in points.
    var x: Double
    var y: Double
    /// preciseLocationInView — sub-pixel Pencil position.
    var px: Double
    var py: Double
    /// Normalized force (0...1 of maximumPossibleForce); 0 when not supported.
    var force: Double
    /// maximumPossibleForce at sample time (device capability ceiling).
    var maxForce: Double
    /// altitudeAngle in radians (0 = flat on screen, pi/2 = perpendicular).
    var altitude: Double
    /// azimuthAngle in radians, direction of tilt.
    var azimuth: Double
    /// "pencil" | "finger" | other UITouch.TouchType raw description.
    var type: String
    /// began | moved | stationary | ended | cancelled.
    var phase: String
    /// UITouch.estimationUpdateIndex when present, else -1. Lets the replay
    /// distinguish estimated (predicted/coalesced) points from finalized ones.
    var estimationUpdateIndex: Int
    /// True if this sample came from event.predictedTouches.
    var predicted: Bool
}

struct CapturedStroke: Codable {
    var id: Int
    var tool: String
    var samples: [TouchSample]
}

struct CaptureSession: Codable {
    var device: String
    var osVersion: String
    /// Screen bounds in points at capture time.
    var viewWidth: Double
    var viewHeight: Double
    /// UIScreen scale (2.0, 3.0...).
    var scale: Double
    var startedAt: String
    var strokes: [CapturedStroke]
}

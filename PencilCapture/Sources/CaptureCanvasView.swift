import UIKit
import SwiftUI

/// A canvas that records every raw UITouch event — including coalesced and
/// predicted samples — and draws simple force-weighted ink as feedback.
/// The captured samples are the deliverable; rendering is deliberately plain.
final class CaptureCanvasView: UIView {
    struct LiveStroke {
        var id: Int
        var touch: UITouch
        var tool: String
        var samples: [TouchSample] = []
        var path = UIBezierPath()
        var lastForce: Double = 0
        var layer: CAShapeLayer?
    }

    private(set) var strokes: [CapturedStroke] = []
    private var live: [ObjectIdentifier: LiveStroke] = [:]
    private var nextStrokeID = 0
    private var sessionStart: TimeInterval = 0
    private var sessionStartDate = Date()
    var onChange: ((Int, Int) -> Void)?

    var sampleCount: Int {
        strokes.reduce(0) { $0 + $1.samples.count } + live.values.reduce(0) { $0 + $1.samples.count }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .systemBackground
        isMultipleTouchEnabled = true
    }

    func clear() {
        strokes.removeAll()
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        live.removeAll()
        nextStrokeID = 0
        sessionStart = 0
        notify()
    }

    func exportJSON() throws -> Data {
        let finished = strokes + live.values
            .sorted { $0.id < $1.id }
            .map { CapturedStroke(id: $0.id, tool: $0.tool, samples: $0.samples) }
        let session = CaptureSession(
            device: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            viewWidth: Double(bounds.width),
            viewHeight: Double(bounds.height),
            scale: Double(UIScreen.main.scale),
            startedAt: ISO8601DateFormatter().string(from: sessionStartDate),
            strokes: finished
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(session)
    }

    // MARK: - Touch capture

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if sessionStart == 0 {
            sessionStart = event?.timestamp ?? ProcessInfo.processInfo.systemUptime
            sessionStartDate = Date()
        }
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard live[key] == nil else { continue }
            var stroke = LiveStroke(
                id: nextStrokeID,
                touch: touch,
                tool: typeName(touch.type)
            )
            nextStrokeID += 1
            stroke.path.lineCapStyle = .round
            stroke.path.lineJoinStyle = .round
            let layer = CAShapeLayer()
            layer.strokeColor = UIColor.label.cgColor
            layer.fillColor = UIColor.clear.cgColor
            layer.lineCap = .round
            self.layer.addSublayer(layer)
            stroke.layer = layer
            stroke.samples.append(sample(touch, phase: "began", event: event))
            stroke.path.move(to: touch.preciseLocation(in: self))
            live[key] = stroke
            redraw(stroke)
        }
        notify()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event else { return }
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard var stroke = live[key] else { continue }

            // Every intermediate sample iOS coalesced into this event.
            for coalesced in event.coalescedTouches(for: touch) ?? [touch] {
                stroke.samples.append(sample(coalesced, phase: "moved", event: event))
                stroke.path.addLine(to: coalesced.preciseLocation(in: self))
            }
            // Predicted samples: kept in the log (flagged) but not drawn.
            for predicted in event.predictedTouches(for: touch) ?? [] {
                var s = sample(predicted, phase: "moved", event: event)
                s.predicted = true
                stroke.samples.append(s)
            }
            live[key] = stroke
            redraw(stroke)
        }
        notify()
    }

    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        // Apple rewrites estimated altitude/azimuth/location after the fact.
        // Record the finalized values so replay can apply the same correction.
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard var stroke = live[key] else { continue }
            var s = sample(touch, phase: "estimated-update", event: nil)
            s.estimationUpdateIndex = touch.estimationUpdateIndex?.intValue ?? -1
            stroke.samples.append(s)
            live[key] = stroke
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches, event: event, phase: "ended")
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches, event: event, phase: "cancelled")
    }

    private func finish(_ touches: Set<UITouch>, event: UIEvent?, phase: String) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard var stroke = live[key] else { continue }
            stroke.samples.append(sample(touch, phase: phase, event: event))
            strokes.append(CapturedStroke(id: stroke.id, tool: stroke.tool, samples: stroke.samples))
            live.removeValue(forKey: key)
        }
        notify()
    }

    // MARK: - Feedback rendering

    private func redraw(_ stroke: LiveStroke) {
        stroke.layer?.path = stroke.path.cgPath
        let f = stroke.samples.last(where: { $0.force > 0 })?.force ?? 0.5
        stroke.layer?.lineWidth = CGFloat(1 + 7 * f)
    }

    private func sample(_ touch: UITouch, phase: String, event: UIEvent?) -> TouchSample {
        let loc = touch.location(in: self)
        let precise = touch.preciseLocation(in: self)
        let azimuthView = touch.azimuthAngle(in: self)
        return TouchSample(
            t: touch.timestamp - sessionStart,
            x: Double(loc.x),
            y: Double(loc.y),
            px: Double(precise.x),
            py: Double(precise.y),
            force: Double(touch.force),
            maxForce: Double(touch.maximumPossibleForce),
            altitude: Double(touch.altitudeAngle),
            azimuth: Double(azimuthView),
            type: typeName(touch.type),
            phase: phase,
            estimationUpdateIndex: touch.estimationUpdateIndex?.intValue ?? -1,
            predicted: false
        )
    }

    private func typeName(_ type: UITouch.TouchType) -> String {
        switch type {
        case .pencil: return "pencil"
        case .direct: return "finger"
        case .indirect: return "indirect"
        case .indirectPointer: return "indirect-pointer"
        @unknown default: return "unknown-\(type.rawValue)"
        }
    }

    private func notify() {
        onChange?(strokes.count + live.count, sampleCount)
    }
}

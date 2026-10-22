# PencilCapture

A minimal iPad app that records raw Apple Pencil / touch input and exports it as JSON
for replay in Inkline's tests.

## What it records

Every `UITouch` event, faithfully:

- `t` — seconds since the session's first touch
- `x`, `y` — location in points
- `px`, `py` — `preciseLocationInView` (sub-pixel Pencil position)
- `force`, `maxForce` — raw pressure and its ceiling (`force / maxForce` normalizes to 0–1)
- `altitude`, `azimuth` — tilt angles (radians)
- `type` — `pencil`, `finger`, `indirect`, etc.
- `phase` — began / moved / stationary / ended / cancelled / estimated-update
- `estimationUpdateIndex` — matches later "estimated-update" samples to the
  points they correct
- `predicted` — true for `predictedTouches` samples (draw-ahead data)

Coalesced touches are recorded individually (each `coalescedTouches(for:)` entry
gets its own sample), so nothing iOS batches is lost. Predicted touches are logged
with `predicted: true` but not drawn.

## Install on your iPad

1. Open `PencilCapture.xcodeproj` in Xcode on your Mac.
2. Select the `PencilCapture` target → Signing & Capabilities → pick your team
   (a free Apple ID works — the app just expires after 7 days).
3. Connect your iPad, select it as the run destination, hit Run.
   (If iOS asks, on the iPad: Settings → Privacy & Security → Developer Mode → on.)

## Capture protocol — draw this once

One export per session gives a reusable test corpus. Suggested sequence:

1. **Handwriting** — write a sentence at normal speed.
2. **Pressure ramp** — one stroke starting light, pressing hard at the end.
3. **Tilt shading** — hold the Pencil at a low angle and shade a broad stroke.
4. **Fast strokes** — quick flick gestures (catches prediction + coalescing).
5. **Slow precise strokes** — small circles, like drawing a diagram.
6. **Palm rest** — rest your palm on the glass and draw through it.
7. **Finger vs Pencil** — one stroke with each (verifies type discrimination).
8. **Double-tap** — double-tap the Pencil barrel a few times.

Then tap **Export** → share sheet → AirDrop to your Mac / Save to Files,
and drop the JSON into the session (or the repo) — it becomes the fixture the
drawing engine's tests replay.

## File format

One JSON object:

```json
{
  "device": "iPad",
  "osVersion": "26.x",
  "viewWidth": 1366.0, "viewHeight": 1024.0, "scale": 2.0,
  "startedAt": "2026-10-22T00:00:00Z",
  "strokes": [
    { "id": 0, "tool": "pencil", "samples": [ { "t": 0.0, "x": ..., ... } ] }
  ]
}
```

## Regenerating the Xcode project

The `.xcodeproj` is generated — sources of truth are `project.yml` and `Sources/`.

```
brew install xcodegen
xcodegen
xcodebuild -scheme PencilCapture \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test
```

# Inkline (iPad app)

SwiftUI + PencilKit note-taking app: paged notebooks, an infinite whiteboard, and page
cards that bring notebook pages onto the whiteboard. Built to the
[design board](../docs/design-board.html) Phase 1 scope.

## Run it on your iPad

```sh
brew install xcodegen          # once
cd Inkline && xcodegen         # regenerate Inkline.xcodeproj after pulling
open Inkline.xcodeproj
```

In Xcode: **Inkline** target → *Signing & Capabilities* → pick your team (a free Apple ID
works, re-run every 7 days) → select your iPad → Run. Needs iPadOS 17+.

## What's in Phase 1

| Area | Behavior |
| --- | --- |
| Ink | Pen, marker, pencil, eraser (whole stroke / pixel), lasso. Apple Pencil draws; fingers never ink. |
| Ink bar | One floating pill. Drag the grip to any edge; it snaps there and remembers the spot per document. Tap a tool to select it, tap it again for colors and widths. |
| Nav element | Back, title (tap to rename), and one menu: theme, page size, rename, delete. |
| Notebook | A5 / A4 / Letter pages stacked vertically. The last page stays blank, so writing on it adds a new one. |
| Whiteboard | 40,000 pt dotted surface, pinch zoom 0.2–5×. |
| Page cards | From a notebook, insert → *Send page to whiteboard*; or on a whiteboard, insert → pick a page. Cards stay linked to the source page until frozen. Finger: long-press drag to move (drag the corner to resize), tap for the menu, double-tap to open the source. |
| Themes | Paper, grid paper, dark, digital, set per document. Dark remaps ink automatically. |
| Undo | Bar buttons, a two-finger tap (undo), or a three-finger tap (redo). Covers ink and card moves/adds/removes. |
| Pencil double-tap | Follows the system setting (switch to eraser / previous tool / show palette). |
| Storage | SwiftData on device; drawings are `PKDrawing` data. |

## Tests

```sh
xcodebuild test -project Inkline.xcodeproj -scheme Inkline \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'
```

- `CaptureReplayTests` replays every capture in [`Tests/Fixtures`](../Tests/Fixtures)
  (recorded with [PencilCapture](../PencilCapture)) through the ink pipeline: only completed
  Pencil strokes become ink, predicted samples are dropped, estimated force/tilt values are
  replaced by their final values, the capture covers the full pressure and tilt range, it survives a
  save/load round trip, the notebook grows a page, and it renders visibly in every theme. To
  add a capture, drop its JSON in that folder.
- `InklineUITests` drives the app: draw, undo, redo, tool options, theme switch, ink bar
  snapping, and sending a page to a whiteboard.
- `ScreenshotTour` (opt-in) seeds the library from a capture and saves screenshots:

  ```sh
  TEST_RUNNER_INKLINE_SCREENSHOT_DIR=/tmp/shots \
  TEST_RUNNER_INKLINE_SEED_FIXTURE=$PWD/../Tests/Fixtures/<capture>.json \
  xcodebuild test -project Inkline.xcodeproj -scheme Inkline \
    -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
    -only-testing:InklineUITests/ScreenshotTour
  ```

In debug builds, launching with `INKLINE_SEED_FIXTURE=<capture.json>` fills an empty library
with that capture.

## Known limits

- The simulator lets the mouse draw (`.anyInput`) so UI tests can ink. On a device, only the Pencil draws.
- Live pressure and tilt response is PencilKit's own. The capture tests check replay,
  storage and rendering, not how drawing feels under your hand.
- The whiteboard is large but finite (40k pt square), not tiled.

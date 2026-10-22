# Inkline

An iPad note-taking and drawing app built for Apple Pencil — notebook pages when you
want structure, an infinite whiteboard when you don't, and embeddable cards that move
between the two.

- `Inkline/` — the iPad app (SwiftUI + PencilKit). See [`Inkline/README.md`](Inkline/README.md)
  to build it onto your iPad.
- `docs/design-board.html` — the product design board (open it in a browser; everything is inline)
- `PencilCapture/` — the stroke-capture harness used to record real Pencil input
  for replay in tests
- `Tests/Fixtures/` — recorded Pencil captures; the app's test suite replays every file here

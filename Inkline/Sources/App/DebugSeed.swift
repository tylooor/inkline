#if DEBUG
import Foundation
import SwiftData
import PencilKit

/// Seeds an empty library from a PencilCapture fixture so the app opens on real
/// handwriting: `INKLINE_SEED_FIXTURE=/path/to/capture.json`.
enum DebugSeed {
    static func runIfRequested(_ context: ModelContext) {
        guard let path = ProcessInfo.processInfo.environment["INKLINE_SEED_FIXTURE"],
              ((try? context.fetchCount(FetchDescriptor<InkDocument>())) ?? 0) == 0,
              let session = try? CaptureReplay.load(URL(fileURLWithPath: path))
        else { return }

        let strokes = CaptureReplay.strokes(from: session)
        let source = CaptureReplay.bounds(of: strokes)
        let ink = PKInk(.pen, color: InkPalette.colors[0])

        func notebook(_ title: String, theme: ThemeID, age: TimeInterval) -> (InkDocument, PKDrawing) {
            let doc = InkDocument(title: title, kind: .notebook, theme: theme)
            let target = doc.layout.pageRect(0).insetBy(dx: 40, dy: 90)
            let drawing = CaptureReplay.drawing(
                from: strokes, ink: ink, baseWidth: 2.2,
                transform: CaptureReplay.fitting(source, into: target)
            )
            doc.drawingData = drawing.dataRepresentation()
            doc.pageCount = doc.layout.pagesNeeded(forInk: drawing.bounds)
            doc.modifiedAt = Date().addingTimeInterval(-age)
            doc.thumbnailData = Renderer.thumbnail(for: doc, drawing: drawing, cards: []).jpegData(compressionQuality: 0.85)
            context.insert(doc)
            return (doc, drawing)
        }

        let (paper, paperDrawing) = notebook("Pencil capture", theme: .paper, age: 0)
        _ = notebook("Pencil capture (dark)", theme: .dark, age: 60)

        let board = InkDocument(title: "Capture board", kind: .whiteboard, theme: .digital)
        let center = SurfaceLayout.whiteboard.whiteboardCenter
        let boardDrawing = CaptureReplay.drawing(
            from: strokes, ink: PKInk(.pen, color: InkPalette.colors[1]), baseWidth: 2.6,
            transform: CGAffineTransform(translationX: center.x - source.midX - 220, y: center.y - source.midY)
        )
        board.drawingData = boardDrawing.dataRepresentation()
        board.modifiedAt = Date().addingTimeInterval(-120)
        context.insert(board)

        let pageSize = paper.pageSize.points
        let cardFrame = CGRect(x: center.x + source.width / 2 - 140, y: center.y - 230, width: 300, height: 300 * pageSize.height / pageSize.width)
        let card = PageCard(sourceID: paper.id, pageIndex: 0, frame: cardFrame)
        context.insert(card)
        board.cards.append(card)
        let render = CardRender(
            id: card.id, frame: cardFrame,
            image: Renderer.pageImage(paper, page: 0, drawing: paperDrawing, scale: 1.5),
            title: "\(paper.title) · p.1", frozen: false
        )
        board.thumbnailData = Renderer.thumbnail(for: board, drawing: boardDrawing, cards: [render]).jpegData(compressionQuality: 0.85)
        try? context.save()
    }
}
#endif

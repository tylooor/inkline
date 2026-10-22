import UIKit
import PencilKit

struct CardRender {
    let id: UUID
    var frame: CGRect
    var image: UIImage?
    var title: String
    var frozen: Bool
}

/// Offscreen rendering of document regions: library thumbnails and page cards.
enum Renderer {
    static func image(
        of region: CGRect, layout: SurfaceLayout, theme: Theme,
        drawing: PKDrawing, cards: [CardRender] = [], scale: CGFloat
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: region.size, format: format).image { c in
            let cg = c.cgContext
            cg.translateBy(x: -region.minX, y: -region.minY)
            BackgroundPainter.paint(region, in: cg, layout: layout, theme: theme)
            for card in cards where card.frame.intersects(region) {
                paintCard(card, in: cg, theme: theme)
            }
            inkImage(drawing, from: region, scale: scale, theme: theme).draw(in: region)
        }
    }

    static func inkImage(_ drawing: PKDrawing, from rect: CGRect, scale: CGFloat, theme: Theme) -> UIImage {
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: theme.interfaceStyle).performAsCurrent {
            image = drawing.image(from: rect, scale: scale)
        }
        return image
    }

    static func pageImage(_ doc: InkDocument, page: Int, drawing: PKDrawing? = nil, scale: CGFloat) -> UIImage {
        let layout = doc.layout
        return image(
            of: layout.pageRect(min(page, layout.pageCount - 1)), layout: layout,
            theme: .of(doc.theme), drawing: drawing ?? doc.drawing, scale: scale
        )
    }

    static func thumbnail(for doc: InkDocument, drawing: PKDrawing, cards: [CardRender], pixelWidth: CGFloat = 480) -> UIImage {
        let layout = doc.layout
        let region: CGRect
        switch layout.kind {
        case .notebook:
            region = layout.pageRect(0)
        case .whiteboard:
            region = whiteboardFocus(layout: layout, drawing: drawing, cards: cards)
        }
        return image(of: region, layout: layout, theme: .of(doc.theme), drawing: drawing, cards: cards,
                     scale: pixelWidth / region.width)
    }

    /// Region around a whiteboard's content, padded and expanded to 4:3.
    static func whiteboardFocus(layout: SurfaceLayout, drawing: PKDrawing, cards: [CardRender]) -> CGRect {
        var content = drawing.strokes.isEmpty ? CGRect.null : drawing.bounds
        for card in cards { content = content.union(card.frame) }
        if content.isNull {
            let c = layout.whiteboardCenter
            content = CGRect(x: c.x - 600, y: c.y - 450, width: 1200, height: 900)
        }
        var r = content.insetBy(dx: -60, dy: -60)
        let aspect: CGFloat = 4.0 / 3.0
        if r.width / r.height > aspect {
            let h = r.width / aspect
            r = CGRect(x: r.minX, y: r.midY - h / 2, width: r.width, height: h)
        } else {
            let w = r.height * aspect
            r = CGRect(x: r.midX - w / 2, y: r.minY, width: w, height: r.height)
        }
        return r
    }

    private static func paintCard(_ card: CardRender, in cg: CGContext, theme: Theme) {
        let path = UIBezierPath(roundedRect: card.frame, cornerRadius: 14).cgPath
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: 4), blur: 16,
                     color: UIColor.black.withAlphaComponent(theme.isDark ? 0.6 : 0.18).cgColor)
        cg.addPath(path)
        cg.setFillColor(theme.surface.cgColor)
        cg.fillPath()
        cg.restoreGState()
        cg.saveGState()
        cg.addPath(path)
        cg.clip()
        card.image?.draw(in: card.frame)
        cg.restoreGState()
    }
}

import UIKit

/// Draws a theme's desk, pages, paper texture and ruling for any region of a surface.
/// Shared by the live tiled background and offscreen renders (thumbnails, cards).
enum BackgroundPainter {
    static let texture: UIImage = makeTexture()

    static func paint(_ rect: CGRect, in ctx: CGContext, layout: SurfaceLayout, theme: Theme) {
        ctx.setFillColor(theme.desk.cgColor)
        ctx.fill(rect)

        switch layout.kind {
        case .notebook:
            for page in layout.pageRects where page.insetBy(dx: -24, dy: -24).intersects(rect) {
                ctx.saveGState()
                ctx.setShadow(
                    offset: CGSize(width: 0, height: 3), blur: 14,
                    color: UIColor.black.withAlphaComponent(theme.isDark ? 0.7 : 0.16).cgColor
                )
                ctx.setFillColor(theme.surface.cgColor)
                ctx.fill(page)
                ctx.restoreGState()

                let visible = page.intersection(rect)
                guard !visible.isNull, !visible.isEmpty else { continue }
                ctx.saveGState()
                ctx.clip(to: visible)
                if theme.textured { fillTexture(visible, ctx) }
                drawPattern(theme.notebookPattern, origin: page.origin, area: visible, page: page, ctx: ctx, theme: theme)
                ctx.restoreGState()
            }
        case .whiteboard:
            ctx.setFillColor(theme.surface.cgColor)
            ctx.fill(rect)
            if theme.textured { fillTexture(rect, ctx) }
            drawPattern(theme.whiteboardPattern, origin: .zero, area: rect, page: nil, ctx: ctx, theme: theme)
        }
    }

    private static func fillTexture(_ rect: CGRect, _ ctx: CGContext) {
        UIGraphicsPushContext(ctx)
        UIColor(patternImage: texture).setFill()
        ctx.fill(rect)
        UIGraphicsPopContext()
    }

    private static func drawPattern(
        _ pattern: Theme.Pattern, origin: CGPoint, area: CGRect, page: CGRect?,
        ctx: CGContext, theme: Theme
    ) {
        ctx.setStrokeColor(theme.line.cgColor)
        ctx.setFillColor(theme.line.cgColor)
        ctx.setLineWidth(0.6)

        switch pattern {
        case .none:
            break

        case .ruled(let s):
            let top = origin.y + s * 3
            let bottom = min(page.map { $0.maxY - s } ?? area.maxY, area.maxY)
            var y = top + ceil(max(0, area.minY - top) / s) * s
            while y <= bottom {
                ctx.move(to: CGPoint(x: area.minX, y: y))
                ctx.addLine(to: CGPoint(x: area.maxX, y: y))
                y += s
            }
            ctx.strokePath()
            if let marginColor = theme.margin, let page {
                let x = page.minX + 56
                if x >= area.minX, x <= area.maxX {
                    ctx.setStrokeColor(marginColor.cgColor)
                    ctx.move(to: CGPoint(x: x, y: area.minY))
                    ctx.addLine(to: CGPoint(x: x, y: area.maxY))
                    ctx.strokePath()
                }
            }

        case .grid(let s):
            var x = origin.x + ceil((area.minX - origin.x) / s) * s
            while x <= area.maxX {
                ctx.move(to: CGPoint(x: x, y: area.minY))
                ctx.addLine(to: CGPoint(x: x, y: area.maxY))
                x += s
            }
            var y = origin.y + ceil((area.minY - origin.y) / s) * s
            while y <= area.maxY {
                ctx.move(to: CGPoint(x: area.minX, y: y))
                ctx.addLine(to: CGPoint(x: area.maxX, y: y))
                y += s
            }
            ctx.strokePath()

        case .dots(let s):
            let r: CGFloat = 1.1
            let start = CGPoint(x: origin.x + s / 2, y: origin.y + s / 2)
            var y = start.y + ceil((area.minY - start.y) / s) * s
            while y <= area.maxY {
                var x = start.x + ceil((area.minX - start.x) / s) * s
                while x <= area.maxX {
                    ctx.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                    x += s
                }
                y += s
            }
            ctx.fillPath()
        }
    }

    /// Deterministic paper grain: fine specks plus a few faint fibers, tiled as a pattern.
    private static func makeTexture() -> UIImage {
        let size = CGSize(width: 192, height: 192)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func random() -> CGFloat {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat(seed >> 33) / CGFloat(UInt64(1) << 31)
        }
        return UIGraphicsImageRenderer(size: size, format: format).image { c in
            for _ in 0..<1800 {
                let alpha = 0.015 + random() * 0.045
                UIColor(white: random() > 0.5 ? 0.3 : 1, alpha: alpha).setFill()
                c.fill(CGRect(x: random() * size.width, y: random() * size.height,
                              width: 0.5 + random(), height: 0.5 + random()))
            }
            let cg = c.cgContext
            cg.setLineWidth(0.4)
            for _ in 0..<36 {
                let start = CGPoint(x: random() * size.width, y: random() * size.height)
                let end = CGPoint(x: start.x + (random() - 0.5) * 24, y: start.y + (random() - 0.5) * 24)
                cg.setStrokeColor(UIColor(red: 0.45, green: 0.36, blue: 0.25, alpha: 0.05).cgColor)
                cg.move(to: start)
                cg.addQuadCurve(to: end, control: CGPoint(x: start.x + (random() - 0.5) * 16, y: end.y))
                cg.strokePath()
            }
        }
    }
}

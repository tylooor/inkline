import CoreGraphics

/// Geometry of a document's canvas in content coordinates (zoom 1).
/// Notebooks stack fixed-size pages vertically; whiteboards are one large open surface.
struct SurfaceLayout: Equatable {
    enum Kind: Equatable { case notebook, whiteboard }

    static let margin: CGFloat = 48
    static let pageGap: CGFloat = 36
    static let whiteboardExtent: CGFloat = 40_000

    var kind: Kind
    var pageSize: CGSize
    var pageCount: Int

    static func notebook(pageSize: CGSize, pageCount: Int) -> SurfaceLayout {
        SurfaceLayout(kind: .notebook, pageSize: pageSize, pageCount: max(pageCount, 1))
    }

    static let whiteboard = SurfaceLayout(kind: .whiteboard, pageSize: .zero, pageCount: 0)

    var contentSize: CGSize {
        switch kind {
        case .notebook:
            let pages = CGFloat(pageCount)
            return CGSize(
                width: pageSize.width + 2 * Self.margin,
                height: 2 * Self.margin + pages * pageSize.height + max(pages - 1, 0) * Self.pageGap
            )
        case .whiteboard:
            return CGSize(width: Self.whiteboardExtent, height: Self.whiteboardExtent)
        }
    }

    var whiteboardCenter: CGPoint {
        CGPoint(x: Self.whiteboardExtent / 2, y: Self.whiteboardExtent / 2)
    }

    func pageRect(_ index: Int) -> CGRect {
        CGRect(
            x: Self.margin,
            y: Self.margin + CGFloat(index) * (pageSize.height + Self.pageGap),
            width: pageSize.width,
            height: pageSize.height
        )
    }

    var pageRects: [CGRect] {
        kind == .notebook ? (0..<pageCount).map(pageRect) : []
    }

    /// Page containing `y`; ink in the gap below a page belongs to that page.
    func pageIndex(containing y: CGFloat) -> Int {
        guard kind == .notebook, pageCount > 0 else { return 0 }
        let raw = Int(((y - Self.margin) / (pageSize.height + Self.pageGap)).rounded(.down))
        return min(max(raw, 0), pageCount - 1)
    }

    /// Infinite-page rule: the last page always stays blank, so ink on it appends a new one.
    func pagesNeeded(forInk bounds: CGRect) -> Int {
        guard kind == .notebook, !bounds.isNull, !bounds.isInfinite else { return pageCount }
        let raw = Int(((bounds.maxY - Self.margin) / (pageSize.height + Self.pageGap)).rounded(.down))
        return max(pageCount, max(raw, 0) + 2)
    }
}

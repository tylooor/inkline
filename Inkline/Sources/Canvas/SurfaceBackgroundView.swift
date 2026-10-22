import UIKit

private final class SurfaceTiledLayer: CATiledLayer {
    override class func fadeDuration() -> CFTimeInterval { 0.05 }
}

/// Tiled background (desk, pages, ruling) drawn lazily per visible tile, so huge
/// whiteboards and deep zoom stay crisp without a giant bitmap.
final class SurfaceBackgroundView: UIView {
    override class var layerClass: AnyClass { SurfaceTiledLayer.self }

    private let lock = NSLock()
    private var layoutState = SurfaceLayout.whiteboard
    private var themeState = Theme.digital

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tiled = layer as! CATiledLayer
        tiled.tileSize = CGSize(width: 512, height: 512)
        tiled.levelsOfDetail = 7
        tiled.levelsOfDetailBias = 4
        isOpaque = true
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(layout: SurfaceLayout, theme: Theme) {
        lock.lock()
        layoutState = layout
        themeState = theme
        lock.unlock()
        backgroundColor = theme.desk
        layer.contents = nil
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        lock.lock()
        let layout = layoutState
        let theme = themeState
        lock.unlock()
        BackgroundPainter.paint(rect, in: ctx, layout: layout, theme: theme)
    }
}

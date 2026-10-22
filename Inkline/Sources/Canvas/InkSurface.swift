import UIKit
import PencilKit

protocol InkSurfaceDelegate: AnyObject {
    func surface(_ surface: InkSurface, drawingDidChange drawing: PKDrawing)
    func surface(_ surface: InkSurface, didMoveCard id: UUID, to frame: CGRect)
    func surface(_ surface: InkSurface, didTapCard id: UUID)
    func surface(_ surface: InkSurface, didDoubleTapCard id: UUID)
    func surfacePencilDoubleTapped(_ surface: InkSurface)
    func surfaceUndoStateChanged(_ surface: InkSurface)
}

/// One PKCanvasView plus the themed background and card layer that scroll and zoom with it.
/// Pencil draws; fingers pan, zoom, move cards, and tap to undo (2 fingers) / redo (3).
final class InkSurface: NSObject {
    let canvas = PKCanvasView()
    weak var delegate: InkSurfaceDelegate?
    private(set) var layout: SurfaceLayout
    private(set) var theme: Theme

    private let background = SurfaceBackgroundView()
    private let cardLayer = UIView()
    private var cardViews: [UUID: CardView] = [:]
    private var needsInitialPosition = true
    private var lastWidth: CGFloat = 0
    private var lastPencilTap = Date.distantPast
    private var drag: (id: UUID, start: CGRect, anchor: CGPoint, resize: Bool)?
    private var cardGestures: [UIGestureRecognizer] = []

    init(layout: SurfaceLayout, theme: Theme, drawing: PKDrawing) {
        self.layout = layout
        self.theme = theme
        super.init()

        canvas.drawing = drawing
        canvas.delegate = self
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        #if targetEnvironment(simulator)
        canvas.drawingPolicy = .anyInput
        #else
        canvas.drawingPolicy = .pencilOnly
        #endif
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.maximumZoomScale = 5
        canvas.accessibilityIdentifier = "ink-canvas"

        for overlay in [background, cardLayer] {
            overlay.layer.anchorPoint = .zero
            overlay.isUserInteractionEnabled = false
        }
        canvas.insertSubview(cardLayer, at: 0)
        canvas.insertSubview(background, at: 0)

        installGestures()
        let pencil = UIPencilInteraction()
        pencil.delegate = self
        canvas.addInteraction(pencil)

        for name in [Notification.Name.NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(undoChanged), name: name, object: nil)
        }

        applyLayout()
        applyTheme()
    }

    // MARK: - Configuration

    func update(layout: SurfaceLayout, theme: Theme) {
        if layout != self.layout {
            self.layout = layout
            applyLayout()
        }
        if theme.id != self.theme.id {
            self.theme = theme
            applyTheme()
        }
    }

    private func applyLayout() {
        let bounds = CGRect(origin: .zero, size: layout.contentSize)
        background.bounds = bounds
        cardLayer.bounds = bounds
        background.configure(layout: layout, theme: theme)
        canvas.alwaysBounceVertical = true
        canvas.alwaysBounceHorizontal = layout.kind == .whiteboard
        syncGeometry()
    }

    private func applyTheme() {
        canvas.overrideUserInterfaceStyle = theme.interfaceStyle
        background.configure(layout: layout, theme: theme)
        canvas.indicatorStyle = theme.isDark ? .white : .black
    }

    // MARK: - Geometry

    /// Call whenever the hosting view lays out.
    func containerDidLayout() {
        let width = canvas.bounds.width
        guard width > 0 else { return }
        let fit = fitZoom
        canvas.minimumZoomScale = layout.kind == .notebook ? fit * 0.5 : 0.2
        if needsInitialPosition || abs(width - lastWidth) > 1 {
            canvas.zoomScale = layout.kind == .notebook ? fit : (needsInitialPosition ? 1 : canvas.zoomScale)
            syncGeometry()
            if needsInitialPosition { scrollToInitialPosition() }
            needsInitialPosition = false
            lastWidth = width
        } else {
            syncGeometry()
        }
    }

    private var fitZoom: CGFloat {
        guard layout.kind == .notebook else { return 1 }
        return min(canvas.bounds.width / layout.contentSize.width, 2)
    }

    private func syncGeometry() {
        let z = canvas.zoomScale
        let size = layout.contentSize
        let scaled = CGSize(width: size.width * z, height: size.height * z)
        if canvas.contentSize != scaled { canvas.contentSize = scaled }
        let transform = CGAffineTransform(scaleX: z, y: z)
        for overlay in [background, cardLayer] {
            overlay.transform = transform
            overlay.layer.position = .zero
        }
        let inset = max(0, (canvas.bounds.width - scaled.width) / 2)
        let insets = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        if canvas.contentInset != insets { canvas.contentInset = insets }
    }

    private func scrollToInitialPosition() {
        let z = canvas.zoomScale
        switch layout.kind {
        case .notebook:
            canvas.contentOffset = CGPoint(x: -canvas.contentInset.left, y: 0)
        case .whiteboard:
            var content = canvas.drawing.strokes.isEmpty ? CGRect.null : canvas.drawing.bounds
            for view in cardViews.values { content = content.union(view.frame) }
            let focus = content.isNull ? layout.whiteboardCenter : CGPoint(x: content.midX, y: content.midY)
            canvas.contentOffset = CGPoint(
                x: focus.x * z - canvas.bounds.width / 2,
                y: focus.y * z - canvas.bounds.height / 2
            )
        }
    }

    /// Visible region in content coordinates.
    var visibleRect: CGRect {
        let z = canvas.zoomScale
        return CGRect(
            x: canvas.contentOffset.x / z, y: canvas.contentOffset.y / z,
            width: canvas.bounds.width / z, height: canvas.bounds.height / z
        )
    }

    var visibleCenter: CGPoint { CGPoint(x: visibleRect.midX, y: visibleRect.midY) }

    var currentPageIndex: Int { layout.pageIndex(containing: visibleCenter.y) }

    // MARK: - Undo

    func undo() { canvas.undoManager?.undo() }
    func redo() { canvas.undoManager?.redo() }
    var canUndo: Bool { canvas.undoManager?.canUndo ?? false }
    var canRedo: Bool { canvas.undoManager?.canRedo ?? false }

    @objc private func undoChanged() {
        delegate?.surfaceUndoStateChanged(self)
    }

    // MARK: - Cards

    func setCards(_ renders: [CardRender]) {
        let ids = Set(renders.map(\.id))
        for (id, view) in cardViews where !ids.contains(id) {
            view.removeFromSuperview()
            cardViews[id] = nil
        }
        for render in renders {
            let view: CardView
            if let existing = cardViews[render.id] {
                view = existing
            } else {
                view = CardView()
                cardLayer.addSubview(view)
                cardViews[render.id] = view
            }
            if drag?.id != render.id { view.frame = render.frame }
            view.configure(render, theme: theme)
        }
    }

    private func card(at point: CGPoint) -> CardView? {
        cardLayer.subviews.reversed().compactMap { $0 as? CardView }.first { $0.frame.contains(point) }
    }

    /// Moves a card and registers the inverse move for undo.
    func moveCard(_ id: UUID, to frame: CGRect, from old: CGRect) {
        cardViews[id]?.frame = frame
        delegate?.surface(self, didMoveCard: id, to: frame)
        canvas.undoManager?.registerUndo(withTarget: self) { surface in
            surface.moveCard(id, to: old, from: frame)
        }
        canvas.undoManager?.setActionName("Move Card")
    }

    // MARK: - Gestures

    private func installGestures() {
        let undoTap = UITapGestureRecognizer(target: self, action: #selector(handleUndoTap))
        undoTap.numberOfTouchesRequired = 2
        undoTap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        let redoTap = UITapGestureRecognizer(target: self, action: #selector(handleRedoTap))
        redoTap.numberOfTouchesRequired = 3
        redoTap.allowedTouchTypes = undoTap.allowedTouchTypes
        undoTap.require(toFail: redoTap)

        let press = UILongPressGestureRecognizer(target: self, action: #selector(handleCardPress))
        press.minimumPressDuration = 0.25
        let cardTap = UITapGestureRecognizer(target: self, action: #selector(handleCardTap))
        let cardDoubleTap = UITapGestureRecognizer(target: self, action: #selector(handleCardDoubleTap))
        cardDoubleTap.numberOfTapsRequired = 2
        cardTap.require(toFail: cardDoubleTap)
        cardGestures = [press, cardTap, cardDoubleTap]
        for gesture in cardGestures {
            gesture.allowedTouchTypes = undoTap.allowedTouchTypes
            gesture.delegate = self
        }

        [undoTap, redoTap, press, cardTap, cardDoubleTap].forEach(canvas.addGestureRecognizer)
    }

    @objc private func handleUndoTap() { undo() }
    @objc private func handleRedoTap() { redo() }

    @objc private func handleCardTap(_ gesture: UITapGestureRecognizer) {
        guard let view = card(at: gesture.location(in: cardLayer)) else { return }
        delegate?.surface(self, didTapCard: view.cardID)
    }

    @objc private func handleCardDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = card(at: gesture.location(in: cardLayer)) else { return }
        delegate?.surface(self, didDoubleTapCard: view.cardID)
    }

    @objc private func handleCardPress(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: cardLayer)
        switch gesture.state {
        case .began:
            guard let view = card(at: point) else { return }
            let corner = CGPoint(x: view.frame.maxX, y: view.frame.maxY)
            let resize = hypot(point.x - corner.x, point.y - corner.y) < 44 / canvas.zoomScale
            drag = (view.cardID, view.frame, point, resize)
            canvas.panGestureRecognizer.isEnabled = false
            cardLayer.bringSubviewToFront(view)
            UIView.animate(withDuration: 0.15) { view.transform = CGAffineTransform(scaleX: 1.03, y: 1.03) }
        case .changed:
            guard let drag, let view = cardViews[drag.id] else { return }
            let dx = point.x - drag.anchor.x
            let dy = point.y - drag.anchor.y
            if drag.resize {
                let aspect = drag.start.height / drag.start.width
                let width = max(140, drag.start.width + dx)
                view.bounds.size = CGSize(width: width, height: width * aspect)
                view.center = CGPoint(x: drag.start.minX + width / 2, y: drag.start.minY + width * aspect / 2)
            } else {
                view.center = CGPoint(x: drag.start.midX + dx, y: drag.start.midY + dy)
            }
        case .ended, .cancelled, .failed:
            canvas.panGestureRecognizer.isEnabled = true
            guard let drag, let view = cardViews[drag.id] else { return }
            self.drag = nil
            UIView.animate(withDuration: 0.15) { view.transform = .identity }
            let final = CGRect(
                x: view.center.x - view.bounds.width / 2, y: view.center.y - view.bounds.height / 2,
                width: view.bounds.width, height: view.bounds.height
            )
            if final != drag.start { moveCard(drag.id, to: final, from: drag.start) }
        default:
            break
        }
    }

    fileprivate func pencilTapped() {
        guard Date().timeIntervalSince(lastPencilTap) > 0.15 else { return }
        lastPencilTap = Date()
        delegate?.surfacePencilDoubleTapped(self)
    }
}

extension InkSurface: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard cardGestures.contains(gesture) else { return true }
        return card(at: gesture.location(in: cardLayer)) != nil
    }
}

extension InkSurface: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        delegate?.surface(self, drawingDidChange: canvasView.drawing)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        syncGeometry()
    }
}

extension InkSurface: UIPencilInteractionDelegate {
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        pencilTapped()
    }

    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        pencilTapped()
    }
}

/// Hosts the surface's canvas inside SwiftUI.
final class SurfaceHostView: UIView {
    let surface: InkSurface

    init(surface: InkSurface) {
        self.surface = surface
        super.init(frame: .zero)
        addSubview(surface.canvas)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        surface.canvas.frame = bounds
        surface.containerDidLayout()
    }
}

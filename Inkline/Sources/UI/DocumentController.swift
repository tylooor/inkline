import SwiftUI
import SwiftData
import PencilKit

struct CardMenuTarget: Identifiable {
    let id: UUID
}

/// Glue between a document's model, its ink surface, and the two chrome elements.
final class DocumentController: ObservableObject {
    let doc: InkDocument
    let surface: InkSurface
    var context: ModelContext?
    var openDocument: ((UUID) -> Void)?

    @Published private(set) var tool: InkTool = .pen
    @Published var optionsTool: InkTool?
    @Published private(set) var colorIndex: [InkTool: Int] = [.pen: 0, .marker: 4, .pencil: 0]
    @Published private(set) var widthIndex: [InkTool: Int] = [.pen: 1, .marker: 1, .pencil: 1]
    @Published var eraserMode: EraserMode = .stroke { didSet { applyTool() } }
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published var cardMenu: CardMenuTarget?
    @Published var showPagePicker = false
    @Published var showBoardPicker = false
    @Published private(set) var themeID: ThemeID
    @Published private(set) var barEdge: InkBarEdge
    @Published private(set) var barPosition: Double

    private var previousTool: InkTool = .pen
    private var saveTask: Task<Void, Never>?
    private var imageCache: [UUID: (stamp: Date, image: UIImage)] = [:]

    init(doc: InkDocument) {
        self.doc = doc
        themeID = doc.theme
        barEdge = doc.inkBarEdge
        barPosition = doc.inkBarPosition
        surface = InkSurface(layout: doc.layout, theme: .of(doc.theme), drawing: doc.drawing)
        surface.delegate = self
        applyTool()
    }

    var isDark: Bool { Theme.of(themeID).isDark }

    // MARK: - Lifecycle

    func didAppear() {
        surface.canvas.undoManager?.removeAllActions()
        refreshCards()
        refreshUndo()
    }

    func didDisappear() {
        saveNow()
    }

    // MARK: - Tools

    func select(_ newTool: InkTool) {
        if newTool == tool {
            optionsTool = newTool.hasOptions ? newTool : nil
        } else {
            previousTool = tool
            tool = newTool
            applyTool()
        }
    }

    func color(for tool: InkTool) -> UIColor {
        InkPalette.colors[colorIndex[tool] ?? 0]
    }

    func width(for tool: InkTool) -> CGFloat {
        let widths = tool.widths
        guard !widths.isEmpty else { return 0 }
        return widths[min(widthIndex[tool] ?? 1, widths.count - 1)]
    }

    func selectedColorIndex(for tool: InkTool) -> Int { colorIndex[tool] ?? 0 }
    func selectedWidthIndex(for tool: InkTool) -> Int { widthIndex[tool] ?? 1 }

    func setColor(_ index: Int, for tool: InkTool) {
        colorIndex[tool] = index
        applyTool()
        optionsTool = nil
    }

    func setWidth(_ index: Int, for tool: InkTool) {
        widthIndex[tool] = index
        applyTool()
        optionsTool = nil
    }

    func toggleEraser() {
        if tool == .eraser {
            tool = previousTool == .eraser ? .pen : previousTool
        } else {
            previousTool = tool
            tool = .eraser
        }
        applyTool()
    }

    func switchToPrevious() {
        let current = tool
        tool = previousTool
        previousTool = current
        applyTool()
    }

    private func applyTool() {
        surface.canvas.tool = pkTool
    }

    var pkTool: PKTool {
        switch tool {
        case .pen, .marker, .pencil:
            return PKInkingTool(tool.inkType!, color: color(for: tool), width: width(for: tool))
        case .eraser:
            return PKEraserTool(eraserMode == .stroke ? .vector : .bitmap)
        case .lasso:
            return PKLassoTool()
        }
    }

    func undo() {
        surface.undo()
        refreshUndo()
    }

    func redo() {
        surface.redo()
        refreshUndo()
    }

    private func refreshUndo() {
        canUndo = surface.canUndo
        canRedo = surface.canRedo
    }

    // MARK: - Ink bar placement

    func setBar(edge: InkBarEdge, position: Double) {
        barEdge = edge
        barPosition = min(max(position, 0), 1)
        doc.inkBarEdge = edge
        doc.inkBarPosition = barPosition
        scheduleSave()
    }

    // MARK: - Document settings

    func setTheme(_ id: ThemeID) {
        doc.theme = id
        themeID = id
        surface.update(layout: doc.layout, theme: .of(id))
        refreshCards()
        saveNow()
    }

    func setPageSize(_ size: PageSize) {
        doc.pageSize = size
        surface.update(layout: doc.layout, theme: .of(doc.theme))
        saveNow()
    }

    func addPage() {
        doc.pageCount += 1
        surface.update(layout: doc.layout, theme: .of(doc.theme))
        scheduleSave()
    }

    func rename(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        doc.title = trimmed
        saveNow()
    }

    func deleteDocument() {
        saveTask?.cancel()
        context?.delete(doc)
        try? context?.save()
    }

    // MARK: - Saving

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        guard !doc.isDeleted else { return }
        let drawing = surface.canvas.drawing
        doc.drawingData = drawing.dataRepresentation()
        doc.modifiedAt = .now
        doc.thumbnailData = Renderer.thumbnail(for: doc, drawing: drawing, cards: cardRenders())
            .jpegData(compressionQuality: 0.85)
        try? context?.save()
    }

    // MARK: - Cards

    func refreshCards() {
        guard doc.kind == .whiteboard else { return }
        surface.setCards(cardRenders())
    }

    private func fetchDocument(_ id: UUID) -> InkDocument? {
        var descriptor = FetchDescriptor<InkDocument>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context?.fetch(descriptor).first
    }

    func cardRenders() -> [CardRender] {
        doc.cards.map { card in
            let source = fetchDocument(card.sourceID)
            let title = source.map { "\($0.title) · p.\(card.pageIndex + 1)" } ?? "Missing page"
            if let data = card.frozenImage, let image = UIImage(data: data) {
                return CardRender(id: card.id, frame: card.frame, image: image, title: title, frozen: true)
            }
            guard let source, card.pageIndex < source.pageCount else {
                return CardRender(id: card.id, frame: card.frame, image: nil, title: "Missing page", frozen: false)
            }
            return CardRender(id: card.id, frame: card.frame, image: liveImage(for: card, source: source), title: title, frozen: false)
        }
    }

    private func liveImage(for card: PageCard, source: InkDocument) -> UIImage {
        if let cached = imageCache[card.id], cached.stamp == source.modifiedAt { return cached.image }
        let pageWidth = source.pageSize.points.width
        let scale = min(max(card.width * 3 / pageWidth, 1), 3)
        let image = Renderer.pageImage(source, page: card.pageIndex, scale: scale)
        imageCache[card.id] = (source.modifiedAt, image)
        return image
    }

    func isFrozen(_ id: UUID) -> Bool {
        doc.cards.first { $0.id == id }?.frozenImage != nil
    }

    func addCard(source: InkDocument, page: Int) {
        let size = source.pageSize.points
        let width: CGFloat = 300
        let height = width * size.height / size.width
        let center = surface.visibleCenter
        let card = PageCard(
            sourceID: source.id, pageIndex: page,
            frame: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        )
        insert(card)
    }

    private func insert(_ card: PageCard) {
        context?.insert(card)
        doc.cards.append(card)
        let id = card.id
        surface.canvas.undoManager?.registerUndo(withTarget: self) { $0.removeCard(id) }
        surface.canvas.undoManager?.setActionName("Add Card")
        refreshCards()
        refreshUndo()
        scheduleSave()
    }

    func removeCard(_ id: UUID) {
        guard let card = doc.cards.first(where: { $0.id == id }) else { return }
        let sourceID = card.sourceID
        let pageIndex = card.pageIndex
        let frame = card.frame
        let frozen = card.frozenImage
        doc.cards.removeAll { $0.id == id }
        context?.delete(card)
        surface.canvas.undoManager?.registerUndo(withTarget: self) { controller in
            let restored = PageCard(sourceID: sourceID, pageIndex: pageIndex, frame: frame)
            restored.frozenImage = frozen
            controller.insert(restored)
        }
        surface.canvas.undoManager?.setActionName("Remove Card")
        refreshCards()
        refreshUndo()
        scheduleSave()
    }

    func toggleFreeze(_ id: UUID) {
        guard let card = doc.cards.first(where: { $0.id == id }) else { return }
        if card.frozenImage != nil {
            card.frozenImage = nil
        } else if let render = cardRenders().first(where: { $0.id == id }), let image = render.image {
            card.frozenImage = image.pngData()
        }
        refreshCards()
        scheduleSave()
    }

    func openSource(_ id: UUID) {
        guard let card = doc.cards.first(where: { $0.id == id }) else { return }
        saveNow()
        openDocument?(card.sourceID)
    }

    /// Clips the page under the viewport onto a whiteboard (a new one when `board` is nil) and opens it.
    func sendCurrentPage(to board: InkDocument?) {
        let page = surface.currentPageIndex
        saveNow()
        let target: InkDocument
        if let board {
            target = board
        } else {
            target = InkDocument(title: "Untitled whiteboard", kind: .whiteboard, theme: .digital)
            context?.insert(target)
        }
        let size = doc.pageSize.points
        let width: CGFloat = 300
        let height = width * size.height / size.width
        let center = SurfaceLayout.whiteboard.whiteboardCenter
        let offset = CGFloat(target.cards.count) * 36
        let card = PageCard(
            sourceID: doc.id, pageIndex: page,
            frame: CGRect(x: center.x - width / 2 + offset, y: center.y - height / 2 + offset, width: width, height: height)
        )
        context?.insert(card)
        target.cards.append(card)
        target.modifiedAt = .now
        try? context?.save()
        openDocument?(target.id)
    }
}

extension DocumentController: InkSurfaceDelegate {
    func surface(_ surface: InkSurface, drawingDidChange drawing: PKDrawing) {
        let needed = doc.layout.pagesNeeded(forInk: drawing.strokes.isEmpty ? .null : drawing.bounds)
        if needed > doc.pageCount {
            doc.pageCount = needed
            surface.update(layout: doc.layout, theme: .of(doc.theme))
        }
        refreshUndo()
        scheduleSave()
    }

    func surface(_ surface: InkSurface, didMoveCard id: UUID, to frame: CGRect) {
        doc.cards.first { $0.id == id }?.frame = frame
        refreshUndo()
        scheduleSave()
    }

    func surface(_ surface: InkSurface, didTapCard id: UUID) {
        cardMenu = CardMenuTarget(id: id)
    }

    func surface(_ surface: InkSurface, didDoubleTapCard id: UUID) {
        openSource(id)
    }

    func surfacePencilDoubleTapped(_ surface: InkSurface) {
        switch UIPencilInteraction.preferredTapAction {
        case .ignore:
            return
        case .switchPrevious:
            switchToPrevious()
        case .showColorPalette, .showInkAttributes:
            optionsTool = tool.isInking ? tool : nil
        default:
            toggleEraser()
        }
    }

    func surfaceUndoStateChanged(_ surface: InkSurface) {
        refreshUndo()
    }
}

import Foundation
import SwiftData
import CoreGraphics
import PencilKit

enum DocumentKind: String, Codable, CaseIterable {
    case notebook, whiteboard

    var label: String { self == .notebook ? "Notebook" : "Whiteboard" }
    var symbol: String { self == .notebook ? "book.closed" : "square.on.square.dashed" }
}

enum PageSize: String, Codable, CaseIterable, Identifiable {
    case a5, a4, letter

    var id: String { rawValue }

    var points: CGSize {
        switch self {
        case .a5: return CGSize(width: 420, height: 595)
        case .a4: return CGSize(width: 595, height: 842)
        case .letter: return CGSize(width: 612, height: 792)
        }
    }

    var label: String {
        switch self {
        case .a5: return "A5"
        case .a4: return "A4"
        case .letter: return "Letter"
        }
    }
}

enum InkBarEdge: String, Codable {
    case top, bottom, leading, trailing

    var isVertical: Bool { self == .leading || self == .trailing }
}

@Model
final class InkDocument {
    @Attribute(.unique) var id: UUID
    var title: String
    var kindRaw: String
    var themeRaw: String
    var pageSizeRaw: String
    var pageCount: Int
    @Attribute(.externalStorage) var drawingData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?
    var inkBarEdgeRaw: String
    var inkBarPosition: Double
    var createdAt: Date
    var modifiedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \PageCard.board) var cards: [PageCard] = []

    init(title: String, kind: DocumentKind, theme: ThemeID, pageSize: PageSize = .a4) {
        id = UUID()
        self.title = title
        kindRaw = kind.rawValue
        themeRaw = theme.rawValue
        pageSizeRaw = pageSize.rawValue
        pageCount = 1
        drawingData = Data()
        thumbnailData = nil
        inkBarEdgeRaw = InkBarEdge.bottom.rawValue
        inkBarPosition = 0.5
        createdAt = .now
        modifiedAt = .now
    }
}

extension InkDocument {
    var kind: DocumentKind {
        get { DocumentKind(rawValue: kindRaw) ?? .notebook }
        set { kindRaw = newValue.rawValue }
    }

    var theme: ThemeID {
        get { ThemeID(rawValue: themeRaw) ?? .paper }
        set { themeRaw = newValue.rawValue }
    }

    var pageSize: PageSize {
        get { PageSize(rawValue: pageSizeRaw) ?? .a4 }
        set { pageSizeRaw = newValue.rawValue }
    }

    var inkBarEdge: InkBarEdge {
        get { InkBarEdge(rawValue: inkBarEdgeRaw) ?? .bottom }
        set { inkBarEdgeRaw = newValue.rawValue }
    }

    var layout: SurfaceLayout {
        kind == .notebook ? .notebook(pageSize: pageSize.points, pageCount: pageCount) : .whiteboard
    }

    var drawing: PKDrawing {
        (try? PKDrawing(data: drawingData)) ?? PKDrawing()
    }
}

/// A page of one document embedded in a whiteboard. Live by default (re-rendered from
/// the source page); `frozenImage` pins a snapshot instead.
@Model
final class PageCard {
    @Attribute(.unique) var id: UUID
    var sourceID: UUID
    var pageIndex: Int
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    @Attribute(.externalStorage) var frozenImage: Data?
    var board: InkDocument?

    init(sourceID: UUID, pageIndex: Int, frame: CGRect) {
        id = UUID()
        self.sourceID = sourceID
        self.pageIndex = pageIndex
        x = frame.minX
        y = frame.minY
        width = frame.width
        height = frame.height
        frozenImage = nil
    }
}

extension PageCard {
    var frame: CGRect {
        get { CGRect(x: x, y: y, width: width, height: height) }
        set {
            x = newValue.minX
            y = newValue.minY
            width = newValue.width
            height = newValue.height
        }
    }
}

import PencilKit

enum InkTool: String, CaseIterable, Identifiable {
    case pen, marker, pencil, eraser, lasso

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .marker: return "highlighter"
        case .pencil: return "pencil"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        }
    }

    var label: String { rawValue.capitalized }

    var inkType: PKInk.InkType? {
        switch self {
        case .pen: return .pen
        case .marker: return .marker
        case .pencil: return .pencil
        case .eraser, .lasso: return nil
        }
    }

    var isInking: Bool { inkType != nil }

    var widths: [CGFloat] {
        switch self {
        case .pen: return [1.5, 3, 6]
        case .marker: return [12, 20, 32]
        case .pencil: return [2, 4, 8]
        case .eraser, .lasso: return []
        }
    }

    var hasOptions: Bool { self != .lasso }
}

enum EraserMode: String, CaseIterable {
    case stroke, pixel
}

enum InkPalette {
    static let colors: [UIColor] = [
        UIColor(hex: 0x1B1D22),
        UIColor(hex: 0x2457C5),
        UIColor(hex: 0xD2372C),
        UIColor(hex: 0x2E8A57),
        UIColor(hex: 0xF2C230),
        UIColor(hex: 0x7B4CC0),
    ]
}

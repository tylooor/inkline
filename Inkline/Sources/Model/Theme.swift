import UIKit

enum ThemeID: String, CaseIterable, Identifiable, Codable {
    case paper, grid, dark, digital

    var id: String { rawValue }
}

/// Per-document look. Ink colors are stored in their light-appearance form; dark themes
/// render the canvas with a dark trait so PencilKit remaps ink automatically.
struct Theme {
    enum Pattern: Equatable {
        case none
        case ruled(CGFloat)
        case grid(CGFloat)
        case dots(CGFloat)
    }

    let id: ThemeID
    let name: String
    let desk: UIColor
    let surface: UIColor
    let line: UIColor
    let margin: UIColor?
    let notebookPattern: Pattern
    let whiteboardPattern: Pattern
    let isDark: Bool
    let textured: Bool

    var interfaceStyle: UIUserInterfaceStyle { isDark ? .dark : .light }

    static func of(_ id: ThemeID) -> Theme {
        switch id {
        case .paper: return .paper
        case .grid: return .grid
        case .dark: return .dark
        case .digital: return .digital
        }
    }

    static let paper = Theme(
        id: .paper, name: "Paper",
        desk: UIColor(hex: 0xE3DBC9), surface: UIColor(hex: 0xF7F1E3),
        line: UIColor(hex: 0xA9B9CF, alpha: 0.75), margin: UIColor(hex: 0xD98C8C, alpha: 0.6),
        notebookPattern: .ruled(28), whiteboardPattern: .none,
        isDark: false, textured: true
    )

    static let grid = Theme(
        id: .grid, name: "Grid paper",
        desk: UIColor(hex: 0xE3DBC9), surface: UIColor(hex: 0xF8F3E8),
        line: UIColor(hex: 0xB8C4D0, alpha: 0.6), margin: nil,
        notebookPattern: .grid(20), whiteboardPattern: .grid(24),
        isDark: false, textured: true
    )

    static let dark = Theme(
        id: .dark, name: "Dark",
        desk: UIColor(hex: 0x000000), surface: UIColor(hex: 0x111113),
        line: UIColor(hex: 0x34343A), margin: nil,
        notebookPattern: .ruled(28), whiteboardPattern: .dots(28),
        isDark: true, textured: false
    )

    static let digital = Theme(
        id: .digital, name: "Digital",
        desk: UIColor(hex: 0xEBEBEE), surface: UIColor(hex: 0xFFFFFF),
        line: UIColor(hex: 0xC4C8D0), margin: nil,
        notebookPattern: .dots(24), whiteboardPattern: .dots(28),
        isDark: false, textured: false
    )
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

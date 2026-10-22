import SwiftUI

/// The single movable ink bar. Drag the grip to any edge; it snaps and remembers its spot
/// per document. Tap a tool to select it, tap it again for options: two taps to anything.
struct InkBar: View {
    @ObservedObject var controller: DocumentController
    let container: CGSize

    @State private var dragOffset: CGSize = .zero

    private let inset: CGFloat = 16
    private var vertical: Bool { controller.barEdge.isVertical }

    /// Fixed footprint: grip 26 + 5 tools + insert + undo/redo at 44, two 9pt separators,
    /// ten 2pt gaps, and 5pt padding each side.
    private static let length: CGFloat = 26 + 8 * 44 + 2 * 9 + 10 * 2 + 2 * 5
    private static let thickness: CGFloat = 44 + 2 * 5
    private var barSize: CGSize {
        vertical ? CGSize(width: Self.thickness, height: Self.length) : CGSize(width: Self.length, height: Self.thickness)
    }

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 2))
        layout {
            grip
            ForEach([InkTool.pen, .marker, .pencil, .eraser, .lasso]) { tool in
                toolButton(tool)
            }
            separator
            insertButton
            separator
            barButton("arrow.uturn.backward", id: "undo", enabled: controller.canUndo, action: controller.undo)
            barButton("arrow.uturn.forward", id: "redo", enabled: controller.canRedo, action: controller.redo)
        }
        .padding(5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
        .fixedSize()
        .frame(width: barSize.width, height: barSize.height)
        .popover(item: $controller.optionsTool) { tool in
            ToolOptions(controller: controller, tool: tool)
                .environment(\.colorScheme, controller.isDark ? .dark : .light)
                .presentationCompactAdaptation(.popover)
        }
        .position(x: center.x + dragOffset.width, y: center.y + dragOffset.height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ink-bar")
    }

    // MARK: - Placement

    private var center: CGPoint {
        center(edge: controller.barEdge, position: controller.barPosition)
    }

    private func center(edge: InkBarEdge, position: Double) -> CGPoint {
        let half = CGSize(width: barSize.width / 2, height: barSize.height / 2)
        let w = container.width
        let h = container.height
        func clampX(_ x: CGFloat) -> CGFloat { min(max(x, half.width + inset), max(w - half.width - inset, half.width + inset)) }
        func clampY(_ y: CGFloat) -> CGFloat { min(max(y, half.height + inset + 56), max(h - half.height - inset, half.height + inset + 56)) }
        switch edge {
        case .bottom: return CGPoint(x: clampX(position * w), y: h - half.height - inset)
        case .top: return CGPoint(x: clampX(position * w), y: half.height + inset)
        case .leading: return CGPoint(x: half.width + inset, y: clampY(position * h))
        case .trailing: return CGPoint(x: w - half.width - inset, y: clampY(position * h))
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let p = CGPoint(x: center.x + value.translation.width, y: center.y + value.translation.height)
                let distances: [(InkBarEdge, CGFloat)] = [
                    (.leading, p.x), (.trailing, container.width - p.x),
                    (.top, p.y), (.bottom, container.height - p.y),
                ]
                let edge = distances.min { $0.1 < $1.1 }!.0
                let position = edge.isVertical ? p.y / max(container.height, 1) : p.x / max(container.width, 1)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    dragOffset = .zero
                    controller.setBar(edge: edge, position: position)
                }
            }
    }

    // MARK: - Pieces

    private var grip: some View {
        Image(systemName: vertical ? "line.3.horizontal" : "line.3.horizontal")
            .rotationEffect(.degrees(vertical ? 0 : 90))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(width: vertical ? 44 : 26, height: vertical ? 26 : 44)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .accessibilityIdentifier("ink-bar-grip")
    }

    private var separator: some View {
        Capsule()
            .fill(Color.primary.opacity(0.12))
            .frame(width: vertical ? 22 : 1, height: vertical ? 1 : 22)
            .padding(vertical ? .vertical : .horizontal, 4)
    }

    private func toolButton(_ tool: InkTool) -> some View {
        let selected = controller.tool == tool
        let tint: Color = tool.isInking ? Color(uiColor: controller.color(for: tool)) : .primary
        return Button { controller.select(tool) } label: {
            Image(systemName: tool.symbol)
                .font(.system(size: 18, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
                .frame(width: 44, height: 44)
                .background(selected ? Color.primary.opacity(0.1) : .clear, in: Circle())
                .overlay(alignment: vertical ? .trailing : .bottom) {
                    if tool.isInking {
                        Circle().fill(Color(uiColor: controller.color(for: tool)))
                            .frame(width: 5, height: 5)
                            .padding(vertical ? .trailing : .bottom, 4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tool-\(tool.rawValue)")
        .accessibilityLabel(tool.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var insertButton: some View {
        if controller.doc.kind == .whiteboard {
            barButton("plus.rectangle.on.rectangle", id: "insert", enabled: true) { controller.showPagePicker = true }
        } else {
            Menu {
                Button { controller.addPage() } label: { Label("Add page", systemImage: "doc.badge.plus") }
                Button { controller.showBoardPicker = true } label: {
                    Label("Send page to whiteboard…", systemImage: "rectangle.portrait.on.rectangle.portrait.angled")
                }
            } label: {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityIdentifier("tool-insert")
        }
    }

    private func barButton(_ symbol: String, id: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityIdentifier("tool-\(id)")
    }
}

/// Options for the selected tool: colors and widths for ink, mode for the eraser.
struct ToolOptions: View {
    @ObservedObject var controller: DocumentController
    let tool: InkTool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tool.label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if tool.isInking {
                HStack(spacing: 12) {
                    ForEach(InkPalette.colors.indices, id: \.self) { i in
                        let selected = controller.selectedColorIndex(for: tool) == i
                        Button { controller.setColor(i, for: tool) } label: {
                            Circle()
                                .fill(Color(uiColor: InkPalette.colors[i]))
                                .frame(width: 28, height: 28)
                                .overlay(Circle().strokeBorder(Color.primary, lineWidth: selected ? 2 : 0).padding(-4))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("color-\(i)")
                    }
                }
                HStack(spacing: 10) {
                    ForEach(tool.widths.indices, id: \.self) { i in
                        let selected = controller.selectedWidthIndex(for: tool) == i
                        Button { controller.setWidth(i, for: tool) } label: {
                            Capsule()
                                .fill(Color.primary)
                                .frame(width: 34, height: max(2, min(tool.widths[i], 14)))
                                .frame(width: 56, height: 38)
                                .background(selected ? Color.primary.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("width-\(i)")
                    }
                }
            } else if tool == .eraser {
                Picker("Eraser", selection: $controller.eraserMode) {
                    Text("Whole stroke").tag(EraserMode.stroke)
                    Text("Pixel").tag(EraserMode.pixel)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
        }
        .padding(18)
    }
}

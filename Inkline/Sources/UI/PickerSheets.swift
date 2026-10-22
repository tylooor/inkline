import SwiftUI
import SwiftData

/// Pick a notebook page to place on the whiteboard as a card.
struct PagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InkDocument.modifiedAt, order: .reverse) private var docs: [InkDocument]
    let excluding: UUID
    let pick: (InkDocument, Int) -> Void

    private var notebooks: [InkDocument] { docs.filter { $0.kind == .notebook && $0.id != excluding } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if notebooks.isEmpty {
                    Text("Create a notebook first — its pages show up here.")
                        .foregroundStyle(.secondary)
                        .padding(40)
                }
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(notebooks) { notebook in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(notebook.title).font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(0..<notebook.pageCount, id: \.self) { page in
                                        Button {
                                            pick(notebook, page)
                                            dismiss()
                                        } label: {
                                            PageThumbnail(doc: notebook, page: page)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("page-\(notebook.title)-\(page)")
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Add a page card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct PageThumbnail: View {
    let doc: InkDocument
    let page: Int
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    Rectangle().fill(Color.secondary.opacity(0.1))
                }
            }
            .frame(width: 120, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            Text("Page \(page + 1)").font(.caption).foregroundStyle(.secondary)
        }
        .task { image = Renderer.pageImage(doc, page: page, scale: 0.6) }
    }
}

/// Pick a whiteboard (or make a new one) to receive the current notebook page.
struct BoardPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InkDocument.modifiedAt, order: .reverse) private var docs: [InkDocument]
    let pick: (InkDocument?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    dismiss()
                    pick(nil)
                } label: {
                    Label("New whiteboard", systemImage: "plus")
                }
                .accessibilityIdentifier("board-new")
                ForEach(docs.filter { $0.kind == .whiteboard }) { board in
                    Button {
                        dismiss()
                        pick(board)
                    } label: {
                        Label(board.title, systemImage: DocumentKind.whiteboard.symbol)
                    }
                }
            }
            .navigationTitle("Send page to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

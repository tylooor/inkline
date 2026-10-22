import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \InkDocument.modifiedAt, order: .reverse) private var docs: [InkDocument]
    let open: (UUID) -> Void

    @State private var renaming: InkDocument?
    @State private var draftTitle = ""

    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 28, alignment: .top)]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 36) {
                    ForEach(docs) { doc in
                        Button { open(doc.id) } label: { LibraryTile(doc: doc) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("doc-\(doc.title)")
                            .contextMenu { contextMenu(for: doc) }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 104)
                .padding(.bottom, 40)
            }

            if docs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "scribble.variable").font(.system(size: 44, weight: .light))
                    Text("Nothing here yet").font(.headline)
                    Text("Start a notebook or a whiteboard from the + menu.").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            LibraryNav(create: create)
                .padding(.leading, 24)
                .padding(.top, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $draftTitle)
            Button("Save") {
                let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if let doc = renaming, !title.isEmpty {
                    doc.title = title
                    try? context.save()
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    @ViewBuilder
    private func contextMenu(for doc: InkDocument) -> some View {
        Button { draftTitle = doc.title; renaming = doc } label: { Label("Rename", systemImage: "pencil") }
        Button(role: .destructive) {
            context.delete(doc)
            try? context.save()
        } label: { Label("Delete", systemImage: "trash") }
    }

    private func create(_ kind: DocumentKind) {
        let doc = InkDocument(
            title: kind == .notebook ? "Untitled notebook" : "Untitled whiteboard",
            kind: kind,
            theme: kind == .notebook ? .paper : .digital
        )
        context.insert(doc)
        try? context.save()
        open(doc.id)
    }
}

/// The library's single rounded-corner nav element: wordmark + create menu.
private struct LibraryNav: View {
    let create: (DocumentKind) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("Inkline")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .padding(.leading, 14)
            Menu {
                Button { create(.notebook) } label: { Label("New notebook", systemImage: DocumentKind.notebook.symbol) }
                Button { create(.whiteboard) } label: { Label("New whiteboard", systemImage: DocumentKind.whiteboard.symbol) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("library-new")
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

private struct LibraryTile: View {
    let doc: InkDocument

    private var aspect: CGFloat {
        let size = doc.pageSize.points
        return doc.kind == .notebook ? size.width / size.height : 4.0 / 3.0
    }

    private var thumbnail: UIImage {
        if let data = doc.thumbnailData, let image = UIImage(data: data) { return image }
        return Renderer.thumbnail(for: doc, drawing: doc.drawing, cards: [], pixelWidth: 240)
    }

    private var subtitle: String {
        let detail: String
        switch doc.kind {
        case .notebook: detail = doc.pageCount == 1 ? "1 page" : "\(doc.pageCount) pages"
        case .whiteboard: detail = doc.cards.count == 1 ? "1 card" : "\(doc.cards.count) cards"
        }
        return "\(doc.kind.label) · \(Theme.of(doc.theme).name) · \(detail)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(aspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: doc.kind == .notebook ? 6 : 14, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
                .frame(height: 230, alignment: .bottom)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

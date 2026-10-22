import SwiftUI

/// The document's single rounded-corner nav element: back, title, and one menu.
struct NavElement: View {
    @ObservedObject var controller: DocumentController
    let close: () -> Void

    @State private var renaming = false
    @State private var draftTitle = ""
    @State private var confirmDelete = false

    private var doc: InkDocument { controller.doc }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: close) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("nav-back")

            Button {
                draftTitle = doc.title
                renaming = true
            } label: {
                Text(doc.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 240)
            }
            .accessibilityIdentifier("nav-title")

            Menu {
                Section("Theme") {
                    ForEach(ThemeID.allCases) { id in
                        Button { controller.setTheme(id) } label: {
                            if controller.themeID == id {
                                Label(Theme.of(id).name, systemImage: "checkmark")
                            } else {
                                Text(Theme.of(id).name)
                            }
                        }
                    }
                }
                if doc.kind == .notebook {
                    Section("Page size") {
                        ForEach(PageSize.allCases) { size in
                            Button { controller.setPageSize(size) } label: {
                                if doc.pageSize == size {
                                    Label(size.label, systemImage: "checkmark")
                                } else {
                                    Text(size.label)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button {
                        draftTitle = doc.title
                        renaming = true
                    } label: { Label("Rename", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("nav-menu")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        .alert("Rename", isPresented: $renaming) {
            TextField("Title", text: $draftTitle)
            Button("Save") { controller.rename(draftTitle) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete \"\(doc.title)\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { controller.deleteDocument() }
            }
        }
    }
}

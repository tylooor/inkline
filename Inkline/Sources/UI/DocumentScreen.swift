import SwiftUI
import SwiftData

struct DocumentScreen: View {
    @Environment(\.modelContext) private var context
    @StateObject private var controller: DocumentController
    let open: (UUID) -> Void
    let close: () -> Void

    init(doc: InkDocument, open: @escaping (UUID) -> Void, close: @escaping () -> Void) {
        _controller = StateObject(wrappedValue: DocumentController(doc: doc))
        self.open = open
        self.close = close
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                SurfaceRepresentable(surface: controller.surface)
                    .ignoresSafeArea()

                InkBar(controller: controller, container: geo.size)

                NavElement(controller: controller, close: closeDocument)
                    .padding(.leading, 20)
                    .padding(.top, 12)
            }
            .environment(\.colorScheme, controller.isDark ? .dark : .light)
        }
        .statusBarHidden(true)
        .onAppear {
            controller.context = context
            controller.openDocument = open
            controller.didAppear()
        }
        .onDisappear { controller.didDisappear() }
        .sheet(isPresented: $controller.showPagePicker) {
            PagePickerSheet(excluding: controller.doc.id) { source, page in
                controller.addCard(source: source, page: page)
            }
        }
        .sheet(isPresented: $controller.showBoardPicker) {
            BoardPickerSheet { board in controller.sendCurrentPage(to: board) }
        }
        .confirmationDialog(
            "Card",
            isPresented: Binding(get: { controller.cardMenu != nil }, set: { if !$0 { controller.cardMenu = nil } }),
            presenting: controller.cardMenu
        ) { target in
            Button("Open page") { controller.openSource(target.id) }
            Button(controller.isFrozen(target.id) ? "Unfreeze (live link)" : "Freeze snapshot") {
                controller.toggleFreeze(target.id)
            }
            Button("Remove card", role: .destructive) { controller.removeCard(target.id) }
        }
    }

    private func closeDocument() {
        controller.saveNow()
        close()
    }
}

struct SurfaceRepresentable: UIViewRepresentable {
    let surface: InkSurface

    func makeUIView(context: Context) -> SurfaceHostView {
        SurfaceHostView(surface: surface)
    }

    func updateUIView(_ uiView: SurfaceHostView, context: Context) {}
}

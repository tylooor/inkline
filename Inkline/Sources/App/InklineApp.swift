import SwiftUI
import SwiftData

@main
struct InklineApp: App {
    let container: ModelContainer = {
        let schema = Schema([InkDocument.self, PageCard.self])
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        }
        let inMemory = ProcessInfo.processInfo.arguments.contains("-UITestInMemory")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not open the Inkline library: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    #if DEBUG
                    DebugSeed.runIfRequested(container.mainContext)
                    #endif
                }
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            LibraryView(open: { path.append($0) })
                .navigationDestination(for: UUID.self) { id in
                    DocumentRoute(
                        id: id,
                        open: { path.append($0) },
                        close: { if !path.isEmpty { path.removeLast() } }
                    )
                }
        }
    }
}

struct DocumentRoute: View {
    @Query private var docs: [InkDocument]
    let open: (UUID) -> Void
    let close: () -> Void

    init(id: UUID, open: @escaping (UUID) -> Void, close: @escaping () -> Void) {
        _docs = Query(filter: #Predicate<InkDocument> { $0.id == id })
        self.open = open
        self.close = close
    }

    var body: some View {
        Group {
            if let doc = docs.first {
                DocumentScreen(doc: doc, open: open, close: close)
            } else {
                Color.clear.onAppear(perform: close)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

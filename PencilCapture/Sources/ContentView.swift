import SwiftUI

struct ContentView: View {
    @State private var canvas = CaptureCanvasView()
    @State private var strokeCount = 0
    @State private var sampleCount = 0
    @State private var exportURL: URL?
    @State private var showingShare = false
    @State private var error: String?

    var body: some View {
        ZStack {
            CanvasRepresentable(canvas: canvas)
                .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(spacing: 16) {
                    Text("\(strokeCount) strokes · \(sampleCount) samples")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)

                    Button("Clear") { canvas.clear() }
                        .buttonStyle(.borderless)

                    Button("Export") { export() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            canvas.onChange = { s, n in
                strokeCount = s
                sampleCount = n
            }
        }
        .sheet(isPresented: $showingShare) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        .alert("Export failed", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func export() {
        do {
            let data = try canvas.exportJSON()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("pencil-capture-\(Int(Date().timeIntervalSince1970)).json")
            try data.write(to: url)
            exportURL = url
            showingShare = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CanvasRepresentable: UIViewRepresentable {
    let canvas: CaptureCanvasView

    func makeUIView(context: Context) -> CaptureCanvasView { canvas }
    func updateUIView(_ uiView: CaptureCanvasView, context: Context) {}
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// Botão "Digitalizar fatura": câmara (iPhone), foto ou ficheiro → OCR → gasto pré-preenchido.
struct ReceiptScanButton: View {
    @State private var isShowingCamera = false
    @State private var isShowingPhotos = false
    @State private var isImportingFile = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var draft: ScannedDraft?
    @State private var errorMessage: String?

    var body: some View {
        Menu {
            if VNDocumentCameraViewController.isSupported {
                Button("Câmara", systemImage: "camera") { isShowingCamera = true }
            }
            Button("Escolher foto", systemImage: "photo") { isShowingPhotos = true }
            Button("Abrir ficheiro", systemImage: "folder") { isImportingFile = true }
        } label: {
            if isScanning {
                ProgressView()
            } else {
                Label("Digitalizar fatura", systemImage: "doc.text.viewfinder")
            }
        }
        .disabled(isScanning)
        .photosPicker(isPresented: $isShowingPhotos, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) {
            guard let item = photoItem else { return }
            photoItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    errorMessage = ReceiptScanner.ScanError.unreadableImage.localizedDescription
                    return
                }
                await scan(data)
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = ReceiptScanner.ScanError.unreadableImage.localizedDescription
                return
            }
            Task { await scan(data) }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            DocumentCameraView { data in
                isShowingCamera = false
                if let data { Task { await scan(data) } }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $draft) { scanned in
            TransactionFormView(prefill: scanned.draft)
        }
        .alert("Não foi possível ler a fatura", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func scan(_ data: Data) async {
        isScanning = true
        defer { isScanning = false }
        do {
            let result = try await ReceiptScanner.scan(imageData: data)
            draft = ScannedDraft(draft: TransactionDraft(scanned: result))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Rascunho vindo do scanner (identificável para a folha).
private struct ScannedDraft: Identifiable {
    let id = UUID()
    let draft: TransactionDraft
}

extension TransactionDraft {
    /// Gasto pré-preenchido com o que o OCR leu; o utilizador confirma no formulário.
    init(scanned: ReceiptParser.Result) {
        self.init(kind: .expense)
        title = scanned.merchant ?? ""
        amount = scanned.amount ?? 0
        currencyCode = scanned.currencyCode
        if let date = scanned.date { self.date = date }
        notes = "Digitalizado de uma fatura"
    }
}

/// Câmara de documentos do VisionKit (recorta e endireita a fatura).
private struct DocumentCameraView: UIViewControllerRepresentable {
    let onFinish: (Data?) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: (Data?) -> Void

        init(onFinish: @escaping (Data?) -> Void) { self.onFinish = onFinish }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish(scan.pageCount > 0 ? scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.9) : nil)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish(nil)
        }
    }
}

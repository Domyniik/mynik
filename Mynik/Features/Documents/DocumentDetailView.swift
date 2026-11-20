import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Detalhe de um documento: dados, validade e fotos (só com Face ID).
struct DocumentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let document: PersonalDocument

    @State private var isEditing = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isImportingFile = false
    @State private var viewing: DocumentPhoto?
    private var lock: BiometricLock { .shared }

    var body: some View {
        let status = DocumentStatus.of(expiry: document.expiryDate, remindDaysBefore: document.remindDaysBefore)
        List {
            Section {
                LabeledContent("Tipo", value: document.kind.title)
                if !document.number.isEmpty {
                    LabeledContent("Número") {
                        Text(lock.isUnlocked ? document.number : DocumentNumber.masked(document.number))
                            .monospaced()
                            .textSelection(.enabled)
                    }
                }
                if !document.issuer.isEmpty {
                    LabeledContent("Emitido por", value: document.issuer)
                }
                LabeledContent("Validade") {
                    Text(DocumentStatus.describe(expiry: document.expiryDate))
                        .foregroundStyle(status == .expired ? .red : status == .expiringSoon ? .orange : .secondary)
                }
                if let expiry = document.expiryDate {
                    LabeledContent("Expira a", value: expiry.formatted(.dateTime.day().month(.wide).year().locale(.app)))
                }
            }

            Section {
                if lock.isUnlocked {
                    if !document.sortedPhotos.isEmpty {
                        photoGrid
                    }
                    PhotosPicker(selection: $pickedItems, maxSelectionCount: 4, matching: .images) {
                        Label("Adicionar fotos", systemImage: "photo.badge.plus")
                    }
                    Button("Importar ficheiro de imagem", systemImage: "folder") { isImportingFile = true }
                } else {
                    Button("Mostrar com \(lock.methodName)", systemImage: lock.symbolName) {
                        Task { await lock.unlock() }
                    }
                }
            } header: {
                Text("Fotos")
            } footer: {
                Text(lock.message ?? (lock.isUnlocked
                    ? "Frente e verso, por exemplo. Toca numa foto para a ver ou partilhar."
                    : "As fotos e o número ficam escondidos até confirmares com \(lock.methodName)."))
            }

            if !document.notes.isEmpty {
                Section("Notas") {
                    Text(document.notes)
                }
            }
        }
        .navigationTitle(document.displayTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar", systemImage: "pencil") {
                    Task {
                        await lock.unlock()
                        if lock.isUnlocked { isEditing = true }
                    }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            DocumentFormView(document: document)
        }
        .sheet(item: $viewing) { photo in
            DocumentPhotoViewer(photo: photo, title: document.displayTitle)
        }
        .onChange(of: pickedItems) { Task { await addPicked() } }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            let images = urls.compactMap { url -> Data? in
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                return try? Data(contentsOf: url)
            }
            add(images)
        }
    }

    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
            ForEach(document.sortedPhotos) { photo in
                Button { viewing = photo } label: {
                    PhotoThumbnail(data: photo.imageData)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Apagar foto", systemImage: "trash", role: .destructive) { delete(photo) }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func addPicked() async {
        var images: [Data] = []
        for item in pickedItems {
            if let data = try? await item.loadTransferable(type: Data.self) { images.append(data) }
        }
        pickedItems = []
        add(images)
    }

    private func add(_ images: [Data]) {
        let next = (document.photos ?? []).map(\.sortOrder).max().map { $0 + 1 } ?? 0
        for (offset, data) in images.enumerated() {
            // Mais resolução do que nas notas, para o texto do documento ficar legível.
            guard let jpeg = ImageDownsampler.jpegData(from: data, maxPixelSize: 2_400, quality: 0.85) else { continue }
            let photo = DocumentPhoto(imageData: jpeg, sortOrder: next + offset)
            modelContext.insert(photo)
            photo.document = document
        }
        try? modelContext.save()
    }

    private func delete(_ photo: DocumentPhoto) {
        withAnimation {
            document.photos?.removeAll { $0 === photo }
            modelContext.delete(photo)
            try? modelContext.save()
        }
    }
}

/// Miniatura quadrada, descodificada fora do `body`.
struct PhotoThumbnail: View {
    let data: Data?
    @State private var image: CGImage?

    var body: some View {
        Color.secondary.opacity(0.1)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipShape(.rect(cornerRadius: 10))
            .task(id: data) {
                guard let data else { return }
                image = ImageDownsampler.cgImage(from: data, maxPixelSize: 400)
            }
    }
}

/// Foto em tamanho grande, com partilha.
struct DocumentPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let photo: DocumentPhoto
    let title: String

    var body: some View {
        NavigationStack {
            Group {
                if let data = photo.imageData, let image = ImageDownsampler.cgImage(from: data, maxPixelSize: 2_400) {
                    let swiftUIImage = Image(decorative: image, scale: 1)
                    ScrollView([.horizontal, .vertical]) {
                        swiftUIImage.resizable().scaledToFit().containerRelativeFrame([.horizontal])
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            ShareLink(item: swiftUIImage, preview: SharePreview(title, image: swiftUIImage))
                        }
                    }
                } else {
                    ContentUnavailableView("Imagem indisponível", systemImage: "photo")
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 500)
        #endif
    }
}

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

enum FileSource: Hashable {
    case folder(URL)
    case kind(FileKind)
    case recent
}

struct FileListView: View {
    let title: String
    let source: FileSource

    @ObservedObject private var store = FileStore.shared
    @ObservedObject private var drive = ExternalDrive.shared
    @State private var items: [FileItem] = []
    @State private var preview: URL?
    @State private var renaming: FileItem?
    @State private var newName = ""
    @State private var showNewFolder = false
    @State private var folderName = ""
    @State private var showImporter = false
    @State private var photoSelection: [PhotosPickerItem] = []

    private var folderURL: URL? {
        if case .folder(let url) = source { return url }
        return nil
    }

    var body: some View {
        Group {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Tidak ada file")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        row(for: item)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if folderURL != nil {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Button { showImporter = true } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Button {
                        folderName = ""
                        showNewFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
        }
        .quickLookPreview($preview)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result, let dir = folderURL {
                store.importFiles(urls, into: dir)
            }
        }
        .onChange(of: photoSelection) { selection in
            guard let dir = folderURL, !selection.isEmpty else { return }
            Task {
                for (index, pick) in selection.enumerated() {
                    if let data = try? await pick.loadTransferable(type: Data.self) {
                        let stamp = Int(Date().timeIntervalSince1970)
                        store.save(data: data, name: "Foto_\(stamp)_\(index + 1).jpg", in: dir)
                    }
                }
                photoSelection = []
            }
        }
        .alert("Folder Baru", isPresented: $showNewFolder) {
            TextField("Nama folder", text: $folderName)
            Button("Buat") {
                if let dir = folderURL { store.makeFolder(named: folderName, in: dir) }
            }
            Button("Batal", role: .cancel) {}
        }
        .alert("Ganti Nama", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Nama", text: $newName)
            Button("Simpan") {
                if let item = renaming { store.rename(item, to: newName) }
                renaming = nil
            }
            Button("Batal", role: .cancel) { renaming = nil }
        }
        .onAppear(perform: reload)
        .onChange(of: store.version) { _ in reload() }
    }

    @ViewBuilder
    private func row(for item: FileItem) -> some View {
        if item.isDirectory {
            NavigationLink(value: FileSource.folder(item.url)) {
                rowContent(item)
            }
            .swipeActions { actions(for: item) }
            .contextMenu { menu(for: item) }
        } else {
            Button {
                preview = item.url
            } label: {
                rowContent(item)
            }
            .buttonStyle(.plain)
            .swipeActions { actions(for: item) }
            .contextMenu { menu(for: item) }
        }
    }

    private func rowContent(_ item: FileItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .font(.system(size: 22))
                .foregroundColor(item.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                Text(subtitle(for: item))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func subtitle(for item: FileItem) -> String {
        var parts: [String] = []
        if !item.isDirectory { parts.append(formatBytes(item.size)) }
        if let date = item.modified {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func actions(for item: FileItem) -> some View {
        Button(role: .destructive) {
            store.delete(item)
        } label: {
            Label("Hapus", systemImage: "trash")
        }
        Button {
            beginRename(item)
        } label: {
            Label("Ganti Nama", systemImage: "pencil")
        }
        .tint(.orange)
    }

    @ViewBuilder
    private func menu(for item: FileItem) -> some View {
        Button { beginRename(item) } label: {
            Label("Ganti Nama", systemImage: "pencil")
        }
        if !item.isDirectory {
            ShareLink(item: item.url) {
                Label("Bagikan", systemImage: "square.and.arrow.up")
            }
            if drive.isOnDrive(item.url) {
                Button { drive.copyToDownloads(item) } label: {
                    Label("Salin ke Unduhan", systemImage: "arrow.down.doc")
                }
            } else if drive.isConnected {
                Button { drive.copyToDrive(item) } label: {
                    Label("Salin ke Flashdisk", systemImage: "externaldrive.badge.plus")
                }
            }
        }
        Button(role: .destructive) { store.delete(item) } label: {
            Label("Hapus", systemImage: "trash")
        }
    }

    private func beginRename(_ item: FileItem) {
        newName = item.name
        renaming = item
    }

    private func reload() {
        switch source {
        case .folder(let url): items = store.contents(of: url)
        case .kind(let kind): items = store.files(of: kind)
        case .recent: items = store.recentFiles()
        }
    }
}

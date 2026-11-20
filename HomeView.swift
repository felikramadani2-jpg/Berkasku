import SwiftUI
import PhotosUI

struct HomeView: View {
    private enum ImportMode { case files, drive }

    @ObservedObject private var store = FileStore.shared
    @ObservedObject private var drive = ExternalDrive.shared

    @State private var counts: [FileKind: (count: Int, size: Int64)] = [:]
    @State private var recentCount = 0
    @State private var storage: (used: Int64, total: Int64) = (0, 0)
    @State private var showImporter = false
    @State private var importMode: ImportMode = .files
    @State private var photoSelection: [PhotosPickerItem] = []

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    storageCard
                    if drive.isConnected { driveCard }

                    LazyVGrid(columns: columns, spacing: 18) {
                        NavigationLink(value: FileSource.folder(store.root)) {
                            tile(symbol: "externaldrive.fill", color: .gray,
                                 title: "Penyimpanan", subtitle: "Folder aplikasi")
                        }
                        NavigationLink(value: FileSource.folder(store.downloads)) {
                            tile(symbol: "arrow.down.circle.fill", color: .orange,
                                 title: "Unduhan", subtitle: "Folder unduhan")
                        }
                        NavigationLink(value: FileSource.recent) {
                            tile(symbol: "clock.fill", color: .blue,
                                 title: "File Baru", subtitle: "\(recentCount) file")
                        }

                        ForEach(FileKind.allCases, id: \.self) { kind in
                            NavigationLink(value: FileSource.kind(kind)) {
                                tile(symbol: kind.symbol, color: kind.color,
                                     title: kind.title, subtitle: subtitle(for: kind))
                            }
                        }

                        Button {
                            importMode = .files
                            showImporter = true
                        } label: {
                            tile(symbol: "folder.badge.plus", color: .green,
                                 title: "Dari Files", subtitle: "Impor file")
                        }

                        PhotosPicker(selection: $photoSelection, matching: .images) {
                            tile(symbol: "photo.on.rectangle.angled", color: .pink,
                                 title: "Galeri", subtitle: "Impor foto")
                        }

                        driveTile
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("BerkasKu")
            .navigationDestination(for: FileSource.self) { source in
                FileListView(title: title(for: source), source: source)
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: importMode == .drive ? [.folder] : [.item],
                allowsMultipleSelection: importMode == .files
            ) { result in
                guard case .success(let urls) = result else { return }
                switch importMode {
                case .files:
                    store.importFiles(urls, into: store.downloads)
                case .drive:
                    if let url = urls.first { drive.connect(url) }
                }
            }
            .onChange(of: photoSelection) { selection in
                guard !selection.isEmpty else { return }
                Task {
                    for (index, pick) in selection.enumerated() {
                        if let data = try? await pick.loadTransferable(type: Data.self) {
                            let stamp = Int(Date().timeIntervalSince1970)
                            store.save(data: data, name: "Foto_\(stamp)_\(index + 1).jpg", in: store.imagesFolder)
                        }
                    }
                    photoSelection = []
                }
            }
            .onAppear(perform: refresh)
            .onChange(of: store.version) { _ in refresh() }
        }
    }

    // MARK: Kartu

    private var storageCard: some View {
        let fraction = storage.total > 0 ? Double(storage.used) / Double(storage.total) : 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Penyimpanan iPhone")
                    .font(.headline)
                Spacer()
                Text("\(Int(fraction * 100))% terpakai")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: fraction)
                .tint(.blue)
            Text("\(formatBytes(storage.used)) dari \(formatBytes(storage.total))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var driveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(drive.name, systemImage: "externaldrive.connected.to.line.below")
                    .font(.headline)
                Spacer()
                Button("Lepas") { drive.disconnect() }
                    .font(.subheadline)
            }
            ProgressView(value: drive.usedFraction)
                .tint(.orange)
            HStack {
                Text("Terpakai \(formatBytes(drive.used))")
                Spacer()
                Text("Sisa \(formatBytes(drive.free))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            Text("Total \(formatBytes(drive.total))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var driveTile: some View {
        if let root = drive.root {
            NavigationLink(value: FileSource.folder(root)) {
                tile(symbol: "externaldrive.connected.to.line.below", color: .orange,
                     title: "Flashdisk", subtitle: "Sisa \(formatBytes(drive.free))")
            }
        } else {
            Button {
                importMode = .drive
                showImporter = true
            } label: {
                tile(symbol: "externaldrive.badge.plus", color: .orange,
                     title: "Flashdisk", subtitle: "Pilih flashdisk")
            }
        }
    }

    private func tile(symbol: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                Image(systemName: symbol)
                    .font(.system(size: 30))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Data

    private func subtitle(for kind: FileKind) -> String {
        guard let info = counts[kind] else { return "0 B (0)" }
        return "\(formatBytes(info.size)) (\(info.count))"
    }

    private func title(for source: FileSource) -> String {
        switch source {
        case .folder(let url):
            if url == store.root { return "Penyimpanan" }
            if url == drive.root { return drive.name }
            return url.lastPathComponent
        case .kind(let kind): return kind.title
        case .recent: return "File Baru"
        }
    }

    private func refresh() {
        let all = store.allFiles()
        var result: [FileKind: (count: Int, size: Int64)] = [:]
        for kind in FileKind.allCases {
            let matched = all.filter { $0.kind == kind }
            result[kind] = (matched.count, matched.reduce(0) { $0 + $1.size })
        }
        counts = result
        let limit = Date().addingTimeInterval(-7 * 86_400)
        recentCount = all.filter { ($0.modified ?? .distantPast) >= limit }.count
        storage = store.deviceStorage()
        drive.refresh()
    }
}

import SwiftUI

// MARK: - Model

enum FileKind: String, CaseIterable, Hashable {
    case image, audio, video, document

    var title: String {
        switch self {
        case .image: return "Gambar"
        case .audio: return "Audio"
        case .video: return "Video"
        case .document: return "Dokumen"
        }
    }

    var symbol: String {
        switch self {
        case .image: return "photo"
        case .audio: return "music.note"
        case .video: return "film"
        case .document: return "doc.text"
        }
    }

    var color: Color {
        switch self {
        case .image: return .purple
        case .audio: return .teal
        case .video: return .red
        case .document: return .blue
        }
    }

    var extensions: Set<String> {
        switch self {
        case .image: return ["jpg", "jpeg", "png", "gif", "heic", "webp", "bmp", "tiff"]
        case .audio: return ["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff"]
        case .video: return ["mp4", "mov", "m4v", "avi", "mkv", "3gp"]
        case .document: return ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv", "pages", "numbers", "key", "md"]
        }
    }

    static func of(_ url: URL) -> FileKind? {
        let ext = url.pathExtension.lowercased()
        return FileKind.allCases.first { $0.extensions.contains(ext) }
    }
}

struct FileItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let modified: Date?

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var kind: FileKind? { isDirectory ? nil : FileKind.of(url) }

    var symbol: String {
        if isDirectory { return "folder.fill" }
        return kind?.symbol ?? "doc"
    }

    var tint: Color {
        if isDirectory { return .orange }
        return kind?.color ?? .gray
    }
}

func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

// MARK: - Store

@MainActor
final class FileStore: ObservableObject {
    static let shared = FileStore()

    let root: URL
    @Published var version = 0

    private let fm = FileManager.default

    static let defaultFolders = ["Unduhan", "Gambar", "Audio", "Video", "Dokumen"]

    init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for name in Self.defaultFolders {
            try? fm.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
    }

    var downloads: URL { root.appendingPathComponent("Unduhan") }
    var imagesFolder: URL { root.appendingPathComponent("Gambar") }

    func bump() { version += 1 }

    private func makeItem(_ url: URL) -> FileItem {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let v = try? url.resourceValues(forKeys: keys)
        return FileItem(
            url: url,
            isDirectory: v?.isDirectory ?? false,
            size: Int64(v?.fileSize ?? 0),
            modified: v?.contentModificationDate
        )
    }

    func contents(of dir: URL) -> [FileItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let urls = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return urls.map(makeItem).sorted {
            let a = ($0.isDirectory ? 0 : 1, $0.name.lowercased())
            let b = ($1.isDirectory ? 0 : 1, $1.name.lowercased())
            return a < b
        }
    }

    /// Semua file (bukan folder) di dalam folder aplikasi, secara rekursif.
    func allFiles() -> [FileItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        guard let e = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }
        var out: [FileItem] = []
        while let url = e.nextObject() as? URL {
            let item = makeItem(url)
            if !item.isDirectory { out.append(item) }
        }
        return out
    }

    func files(of kind: FileKind) -> [FileItem] {
        allFiles()
            .filter { $0.kind == kind }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    func recentFiles(days: Int = 7) -> [FileItem] {
        let limit = Date().addingTimeInterval(-Double(days) * 86_400)
        return allFiles()
            .filter { ($0.modified ?? .distantPast) >= limit }
            .sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    /// Kapasitas penyimpanan perangkat (bukan hanya folder aplikasi).
    func deviceStorage() -> (used: Int64, total: Int64) {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        let v = try? root.resourceValues(forKeys: keys)
        let total = Int64(v?.volumeTotalCapacity ?? 0)
        let free = v?.volumeAvailableCapacityForImportantUsage ?? 0
        return (max(total - free, 0), total)
    }

    // MARK: Operasi file

    func uniqueURL(in dir: URL, name: String) -> URL {
        var candidate = dir.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var i = 1
        repeat {
            let newName = ext.isEmpty ? "\(base) (\(i))" : "\(base) (\(i)).\(ext)"
            candidate = dir.appendingPathComponent(newName)
            i += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }

    func delete(_ item: FileItem) {
        try? fm.removeItem(at: item.url)
        bump()
    }

    func rename(_ item: FileItem, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }
        let dest = item.url.deletingLastPathComponent().appendingPathComponent(trimmed)
        guard !fm.fileExists(atPath: dest.path) else { return }
        try? fm.moveItem(at: item.url, to: dest)
        bump()
    }

    func makeFolder(named name: String, in dir: URL) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let dest = uniqueURL(in: dir, name: trimmed)
        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
        bump()
    }

    /// Salin file yang dipilih dari app Files (butuh security-scoped access).
    func importFiles(_ urls: [URL], into dir: URL) {
        for src in urls {
            let scoped = src.startAccessingSecurityScopedResource()
            defer { if scoped { src.stopAccessingSecurityScopedResource() } }
            let dest = uniqueURL(in: dir, name: src.lastPathComponent)
            try? fm.copyItem(at: src, to: dest)
        }
        bump()
    }

    func save(data: Data, name: String, in dir: URL) {
        let dest = uniqueURL(in: dir, name: name)
        try? data.write(to: dest)
        bump()
    }
}

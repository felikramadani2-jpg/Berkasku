import SwiftUI

/// Mengelola akses ke flashdisk yang dipilih pengguna lewat pemilih folder.
/// iOS tidak mengizinkan aplikasi mendeteksi flashdisk sendiri, jadi pengguna
/// memilih flashdisk di pemilih folder, lalu aplikasi membaca kapasitasnya.
@MainActor
final class ExternalDrive: ObservableObject {
    static let shared = ExternalDrive()

    @Published private(set) var root: URL?
    @Published private(set) var name = "Flashdisk"
    @Published private(set) var total: Int64 = 0
    @Published private(set) var free: Int64 = 0

    private var scoped = false

    var isConnected: Bool { root != nil }
    var used: Int64 { max(total - free, 0) }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    func connect(_ url: URL) {
        disconnect()
        scoped = url.startAccessingSecurityScopedResource()
        root = url
        refresh()
    }

    func disconnect() {
        if scoped, let root { root.stopAccessingSecurityScopedResource() }
        scoped = false
        root = nil
        total = 0
        free = 0
        name = "Flashdisk"
    }

    /// Baca ulang kapasitas. Jika flashdisk sudah dicabut, koneksi dilepas.
    func refresh() {
        guard let root else { return }
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeNameKey
        ]
        guard FileManager.default.fileExists(atPath: root.path),
              let v = try? root.resourceValues(forKeys: keys),
              let totalBytes = v.volumeTotalCapacity, totalBytes > 0 else {
            disconnect()
            return
        }
        total = Int64(totalBytes)
        free = Int64(v.volumeAvailableCapacity ?? 0)
        name = v.volumeName ?? "Flashdisk"
    }

    /// Salin file dari penyimpanan aplikasi ke akar flashdisk.
    func copyToDrive(_ item: FileItem) {
        guard let root else { return }
        let dest = FileStore.shared.uniqueURL(in: root, name: item.name)
        try? FileManager.default.copyItem(at: item.url, to: dest)
        FileStore.shared.bump()
        refresh()
    }

    /// Salin file dari flashdisk ke folder Unduhan aplikasi.
    func copyToDownloads(_ item: FileItem) {
        let store = FileStore.shared
        let dest = store.uniqueURL(in: store.downloads, name: item.name)
        try? FileManager.default.copyItem(at: item.url, to: dest)
        store.bump()
    }

    func isOnDrive(_ url: URL) -> Bool {
        guard let root else { return false }
        return url.path.hasPrefix(root.path)
    }
}

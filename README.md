# BerkasKu — pengelola file sederhana untuk iPhone (SwiftUI, iOS 16+)

Aplikasi orisinal dengan fungsi mirip pengelola file: beranda kategori
(Gambar, Audio, Video, Dokumen, File Baru, Unduhan), penjelajah folder,
pratinjau file (Quick Look), ganti nama, hapus, bagikan, buat folder, impor
dari app Files dan dari Galeri.

Catatan penting: iOS tidak mengizinkan aplikasi pihak ketiga membaca seluruh
penyimpanan iPhone. BerkasKu mengelola folder aplikasinya sendiri, yang juga
muncul di app Files bawaan (Files > Di iPhone-ku > BerkasKu).

## Flashdisk
1. Colok flashdisk ke iPhone X lewat adaptor Lightning ke USB (Camera Adapter).
2. Buka BerkasKu, ketuk kotak "Flashdisk", lalu pilih flashdisk di pemilih folder.
3. Beranda menampilkan kartu kapasitas: terpakai, sisa, dan total (GB).
4. Tekan lama sebuah file untuk "Salin ke Flashdisk" atau "Salin ke Unduhan".

iOS tidak mengizinkan aplikasi mendeteksi flashdisk otomatis, jadi flashdisk
perlu dipilih ulang setiap kali dicolok. Format yang didukung: FAT32, exFAT, APFS.

## Membuat IPA tanpa Mac (GitHub Actions)
1. Buat repositori baru di github.com, lalu unggah ISI folder ini
   (`project.yml`, folder `BerkasKu`, folder `.github`) ke cabang `main`,
   sehingga `project.yml` berada di akar repositori.
2. Buka tab Actions > Build IPA. Build berjalan otomatis setiap ada push,
   atau tekan "Run workflow".
3. Setelah selesai (sekitar 5-10 menit), unduh artifact `BerkasKu-ipa`
   di bagian bawah halaman run, lalu ekstrak untuk mendapat `BerkasKu.ipa`.
4. IPA ini belum ditandatangani. Pasang lewat Sideloadly atau AltStore dari
   komputer Windows/Mac dengan Apple ID Anda (berlaku 7 hari untuk Apple ID gratis).

## Cara membuat IPA (butuh Mac dengan Xcode 14.3+)

### Opsi A — XcodeGen (paling cepat)
1. Pasang XcodeGen: `brew install xcodegen`
2. Di folder ini jalankan: `xcodegen`
3. Buka `BerkasKu.xcodeproj` di Xcode.

### Opsi B — manual
1. Xcode > File > New > Project > iOS > App. Nama: BerkasKu, Interface: SwiftUI,
   Language: Swift. Minimum Deployments: iOS 16.0.
2. Hapus `ContentView.swift` bawaan dan ganti isi `BerkasKuApp.swift`.
3. Seret keempat file `.swift` dari folder `BerkasKu/` ke proyek.
4. Di target > Info, tambahkan:
   - `UIFileSharingEnabled` = YES
   - `LSSupportsOpeningDocumentsInPlace` = YES

### Menjalankan di iPhone X (iOS 16.7.x)
1. Colok iPhone, aktifkan Developer Mode (Pengaturan > Privasi & Keamanan).
2. Di Xcode: Signing & Capabilities > pilih Team (Apple ID gratis boleh),
   ubah Bundle Identifier jadi unik.
3. Pilih iPhone Anda sebagai tujuan, tekan Run.
   Apple ID gratis: aplikasi berlaku 7 hari lalu perlu dipasang ulang.

### Membuat file .ipa
1. Pilih tujuan "Any iOS Device (arm64)", lalu Product > Build.
2. Di Navigator > Products, klik kanan `BerkasKu.app` > Show in Finder.
3. Buat folder `Payload`, taruh `BerkasKu.app` di dalamnya,
   kompres folder `Payload`, lalu ganti ekstensi `.zip` menjadi `.ipa`.
4. Pasang lewat AltStore atau Sideloadly (keduanya menandatangani ulang dengan Apple ID Anda).

Kode belum diuji kompilasi di Xcode (dibuat di lingkungan Linux). Jika ada
error saat build, kirimkan pesan error-nya agar bisa diperbaiki.

# Nihong Jastip Mobile

Aplikasi operasional Nihong Jastip yang dibangun dengan Flutter. Repository ini
berdiri terpisah dari aplikasi web `nihong-team`; keduanya berbagi kontrak
Firebase/Firestore, bukan source code.

## Menjalankan aplikasi

```bash
flutter pub get
flutter run
```

Login memakai Firebase Authentication pada project utama dan NihongStore.
Aktifkan metode Email/Password pada kedua project dan pastikan UID akun di
project NihongStore memiliki dokumen `admins/{uid}`. Kedua sesi dipulihkan saat
aplikasi dibuka kembali; akses operasional ditolak jika validasi store gagal.

## Struktur `lib/`

- `app/`: bootstrap UI dan konfigurasi `go_router`
- `core/design_system/`: warna brand dan tema Material
- `core/widgets/`: komponen bersama untuk badge, loading, placeholder, dan 404
- `features/`: layar dikelompokkan menurut fitur
- `features/public_links/`: route publik terpisah dari route admin
- `features/auth/data/`: repository Firebase Authentication
- `features/auth/presentation/`: layar login dan state autentikasi

## Pemeriksaan lokal

```bash
dart format lib
flutter analyze
```

Panduan untuk memahami struktur project, kode, dan teknologinya ada di
[`docs/panduan-memahami-project-mobile.md`](docs/panduan-memahami-project-mobile.md).

Panduan konfigurasi signing dan build distribusi ada di
[`docs/mobile-release-checklist.md`](docs/mobile-release-checklist.md).

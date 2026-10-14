# Persiapan build rilis mobile

## Identitas aplikasi

- Android `applicationId`: `com.nihongjastip`
- iOS Bundle ID: `com.nihongjastip`
- Versi aplikasi berada di `pubspec.yaml` pada field `version`.
- Pastikan aplikasi dengan ID tersebut sudah terdaftar pada Firebase production untuk kedua platform.

## Android

Build release tidak lagi ditandatangani dengan debug key. Untuk menyiapkan signing:

1. Buat upload keystore dan simpan di lokasi pribadi yang aman. Jangan masukkan ke repository atau kirim lewat chat.
2. Salin `android/key.properties.example` menjadi `android/key.properties`.
3. Isi `storeFile`, `storePassword`, `keyAlias`, dan `keyPassword`. Path `storeFile` dihitung dari folder `android/`.
4. Simpan file keystore di lokasi yang sesuai dengan `storeFile`; `.gitignore` sudah mengecualikan key properties dan file keystore.
5. Buat artefak untuk Google Play:

   ```bash
   flutter build appbundle --release
   ```

   Untuk APK langsung:

   ```bash
   flutter build apk --release
   ```

Tanpa `android/key.properties`, build release tetap bisa dikompilasi sebagai artefak unsigned untuk pemeriksaan, tetapi belum siap dipasang atau diunggah ke store.

## iOS

Build IPA memerlukan macOS, akun Apple Developer, signing certificate, dan provisioning profile untuk Bundle ID `com.nihongjastip`. Atur Team dan signing pada target Runner di Xcode, lalu jalankan:

```bash
flutter build ipa --release
```

## Pemeriksaan sebelum distribusi

- Pastikan Firebase Android dan iOS mengarah ke project production yang benar.
- Pastikan Email/Password aktif pada Firebase Auth utama dan NihongStore, serta UID admin terdaftar di `admins/{uid}` pada project NihongStore.
- Pastikan admin dapat membuka inbox, mengubah stok, menjadwalkan pesanan, membatalkan booking, dan melihat status yang tersinkron.
- Jalankan `dart format lib` dan `flutter analyze`.
- Simpan backup keystore dan kredensial signing di password manager milik organisasi.

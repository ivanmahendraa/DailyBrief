# DailyBrief

DailyBrief adalah aplikasi Flutter Android dan iOS untuk meminta informasi
hari, tanggal, waktu, lokasi, dan cuaca melalui suara. Pengguna menyentuh area
utama, mendengar konfirmasi, lalu menerima jawaban melalui text-to-speech (TTS).

## Fitur

- Perintah suara berbahasa Indonesia untuk hari, tanggal, waktu, cuaca, dan
  lokasi.
- Area sentuh utama berlabel semantik dan umpan balik haptik.
- Informasi cuaca OpenWeatherMap; nama lokasi berasal dari geocoder bawaan
  platform Android/iOS.
- Riwayat kategori perintah di Cloud Firestore untuk pengguna anonim. Aplikasi
  tidak menyimpan audio, transkrip, jawaban, atau koordinat.
- Firebase Crashlytics pada build release Android dan iOS. Firebase Analytics
  tidak digunakan.
- Sapaan Home otomatis dilewati saat perangkat melaporkan navigasi aksesibel
  (misalnya TalkBack atau VoiceOver) agar suaranya tidak bertumpuk.

## Prasyarat

- Flutter SDK dan Dart yang memenuhi constraint pada `pubspec.yaml`.
- Android Studio/Android SDK untuk menjalankan atau membangun Android.
- macOS dengan Xcode untuk membangun atau menjalankan iOS. Build iOS tidak
  dapat dilakukan dari Windows.
- Perangkat/emulator untuk mencoba mikrofon, lokasi, dan text-to-speech.

Proyek ini menggunakan Dart SDK `^3.13.3`; hasil verifikasi di bawah dijalankan
dengan Flutter 3.47.7 dan Dart 3.13.5.

Periksa instalasi Flutter dan perangkat yang dikenali:

```powershell
flutter doctor
flutter devices
```

## Menyiapkan proyek

Jalankan dari root repositori:

```powershell
flutter pub get
```

Konfigurasi Firebase Android, iOS, dan Web telah dibuat untuk project
`dailybrief-ivanmahendraa`. Jika project Firebase atau aplikasi platform
berubah, pasang FlutterFire CLI dan buat ulang konfigurasi:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure --project=dailybrief-ivanmahendraa --platforms=android,ios,web
```

File aturan Firestore berada di `firestore.rules`. Setelah meninjau perubahan,
deploy aturan hanya dengan akun Firebase yang berwenang:

```powershell
firebase deploy --only firestore:rules --project=dailybrief-ivanmahendraa
```

## Konfigurasi API cuaca

Cuaca menggunakan OpenWeatherMap Current Weather API. Salin contoh konfigurasi
dan isi key Anda di file lokal `.env`:

```powershell
Copy-Item .env.example .env
```

Edit `.env`, lalu jalankan:

```powershell
flutter run --dart-define-from-file=.env
```

Alternatif tanpa file:

```powershell
flutter run --dart-define=OPENWEATHER_API_KEY=YOUR_API_KEY
```

Key bersifat opsional untuk menjalankan aplikasi; tanpa key, permintaan cuaca
menampilkan status layanan belum dikonfigurasi. `.env` masuk `.gitignore` dan
tidak boleh di-commit.

**Penting:** `--dart-define` hanya menghindari hard-code key di sumber,
bukan menyembunyikannya dari binary aplikasi yang didistribusikan. Batasi key
sesuai kemampuan penyedia, pantau kuota, dan gunakan backend/proxy dengan
secret server-side untuk produksi jika key harus dirahasiakan. Jangan
menaruh key nyata pada dokumentasi, commit, log, atau screenshot.

Reverse geocoding menggunakan geocoder bawaan Android/iOS dan tidak memerlukan
Google Geocoding API key tersendiri. Hasilnya bergantung pada layanan platform
dan mungkin memerlukan koneksi jaringan.

## Menjalankan aplikasi

Tanpa konfigurasi API cuaca:

```powershell
flutter run
```

Dengan `.env`:

```powershell
flutter run --dart-define-from-file=.env
```

Pilih perangkat tertentu dengan `-d <device-id>` setelah memeriksa `flutter
devices`. Izin mikrofon dan lokasi diminta oleh layanan terkait saat
dibutuhkan. Di iOS, tujuan izin dijelaskan pada `ios/Runner/Info.plist`.

## Memeriksa dan membangun

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

APK debug dihasilkan di
`build/app/outputs/flutter-apk/app-debug.apk`. Untuk iOS, gunakan macOS/Xcode:

```powershell
flutter build ios
```

Build release harus dilengkapi konfigurasi penandatanganan dan konfigurasi
layanan produksi yang sesuai sebelum didistribusikan. Crashlytics mengumpulkan
crash hanya pada build release Android/iOS; debug tidak mengaktifkan
pengumpulan.

## Data, Firebase, dan privasi

- Firestore hanya menyimpan kategori perintah yang didukung dan timestamp
  server pada `users/{uid}/command_history`.
- Firebase Authentication membuat pengguna anonim. Aturan
  `firestore.rules` membatasi akses ke UID pemilik, membatasi field yang boleh
  ditulis, dan menolak update.
- Audio, transkrip ucapan, teks jawaban, dan koordinat lokasi tidak disimpan
  sebagai riwayat.
- Firebase Analytics tidak diintegrasikan.
- Crashlytics dinonaktifkan secara default dan hanya diaktifkan ketika aplikasi
  berjalan dalam mode release Android/iOS. Pesan exception yang dikirim dari
  handler global dibuat generik; stack trace tetap dikirim untuk diagnosis.
  Handler tetap menampilkan error asli secara lokal di debug.

## Hasil verifikasi terakhir

Pada 4 November 2026:

- `flutter test` — 271 tes lulus.
- `flutter analyze` — tidak menemukan masalah.
- `flutter build apk --debug` — berhasil.

Validasi perangkat fisik, pengaktifan TalkBack/VoiceOver, konfigurasi Firebase
Console, dan key produksi harus dilakukan di lingkungan/rilis terkait; hasil
tes otomatis bukan pengganti pemeriksaan tersebut.

# DailyBrief

DailyBrief adalah aplikasi Flutter Android dan iOS untuk meminta informasi
hari, tanggal, waktu, lokasi, dan cuaca melalui suara. Pengguna menyentuh area
utama, mendengar konfirmasi, lalu menerima jawaban dan penanda siap-bertanya
kembali melalui text-to-speech (TTS).

## Fitur

- Perintah suara berbahasa Indonesia untuk hari, tanggal, waktu, cuaca, dan
  lokasi.
- Setelah jawaban berhasil dibacakan, DailyBrief menyampaikan bahwa ia siap
  menerima pertanyaan berikutnya sebelum kembali ke status siap.
- Area sentuh utama berlabel semantik dan umpan balik haptik.
- Pintasan Android melalui tombol Accessibility Button untuk membuka Home dan
  memulai interaksi suara setelah tindakan eksplisit pengguna.
- Informasi cuaca Open-Meteo dan nama lokasi dari OpenStreetMap Nominatim,
  menggunakan koordinat GPS perangkat.
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

## Data cuaca dan lokasi

Cuaca diambil dari Open-Meteo Forecast API dan data historis Open-Meteo Archive
API; pencarian nama tempat serta reverse geocoding menggunakan OpenStreetMap
Nominatim. Keduanya tidak memerlukan API key untuk penggunaan
pribadi/non-komersial, sehingga tidak diperlukan file `.env` atau
`--dart-define` untuk menjalankan aplikasi.
Informasi atribusi kedua sumber tersedia melalui ikon info pada halaman Home.

Cuaca untuk hari ini memakai kondisi terkini. Data hingga tujuh hari lalu
menggunakan fitur past-days Forecast API, sedangkan tanggal yang lebih lama
menggunakan Archive API. Prakiraan tanggal mendatang tersedia sampai 16 hari;
tanggal yang lebih jauh akan dijelaskan sebagai di luar jangkauan prakiraan.
Data historis dapat memiliki jeda ketersediaan dari penyedia.

Open-Meteo free API dibatasi untuk penggunaan non-komersial, memiliki batas
permintaan, dan tidak menjamin uptime. Data cuacanya dilisensikan CC BY 4.0.
Nominatim publik memiliki batas maksimum satu permintaan per detik untuk
aplikasi, mensyaratkan identitas `User-Agent` dan atribusi, serta dapat
membatasi layanan yang melampaui kebijakannya. Aplikasi membatasi laju
permintaan dan menyimpan hasil reverse geocoding dalam cache selama proses
berjalan. Untuk penggunaan komersial atau trafik aplikasi yang lebih besar,
gunakan layanan berlisensi atau server/proxy sendiri.

Koordinat GPS atau koordinat tempat yang dicari dikirim ke Open-Meteo saat
meminta cuaca. Nama tempat yang diketik/diucapkan dikirim ke Nominatim untuk
pencarian; koordinat GPS dikirim ke Nominatim saat meminta nama lokasi.
Jika nama tempat menyebut Batam, pencarian dibatasi ke wilayah Batam dan hasil
divalidasi sebagai wilayah Indonesia/Batam. Jika hasil tidak cocok atau nama
tempat cocok dengan beberapa lokasi, aplikasi meminta rincian tambahan.
Koordinat dan jawaban tetap tidak disimpan sebagai riwayat di Cloud Firestore.

## Menjalankan aplikasi

```powershell
flutter run
```

Pilih perangkat tertentu dengan `-d <device-id>` setelah memeriksa `flutter
devices`. Izin mikrofon dan lokasi diminta oleh layanan terkait saat
dibutuhkan. Di iOS, tujuan izin dijelaskan pada `ios/Runner/Info.plist`.

## Pintasan aksesibilitas Android

DailyBrief mendaftarkan layanan **DailyBrief Accessibility Shortcut**. Layanan
ini hanya merespons tombol Aksesibilitas Android; layanan tidak membaca isi
layar aplikasi lain. Layanan tidak dinyalakan otomatis dan tidak meminta izin
mikrofon saat diaktifkan.

1. Dari Home DailyBrief, buka ikon info lalu pilih **Panduan pintasan
   aksesibilitas**.
2. Pilih **Buka pengaturan**, atau buka Pengaturan Android > Aksesibilitas >
   layanan/aplikasi yang diinstal. Nama dan letak menu dapat berbeda menurut
   produsen.
3. Aktifkan **DailyBrief Accessibility Shortcut** secara manual dan setujui
   dialog Android. Untuk menonaktifkannya, matikan layanan pada halaman yang
   sama.
4. Gunakan tombol Aksesibilitas di bilah navigasi layar atau gestur pintasan
   yang disediakan perangkat. Tombol/gestur harus tersedia dan ditetapkan untuk
   layanan ini.

Tombol Aksesibilitas memerlukan Android 8.0 (API 26) atau lebih baru dan tidak
tersedia pada semua mode navigasi/perangkat. Kombinasi tahan Volume Naik +
Volume Turun adalah pintasan sistem yang dapat mengubah status layanan pada
perangkat yang mendukungnya; kombinasi itu **tidak** mengirim event tombol
biasa ke DailyBrief dan tidak membuka aplikasi. Tombol Power tidak dapat
diambil alih aplikasi pihak ketiga.

Setelah tombol Aksesibilitas ditekan, Android dapat mengizinkan DailyBrief
membuka Home. Pembukaan dari latar belakang tetap tunduk pada pembatasan Android
dan kebijakan produsen, sehingga tidak dijamin pada setiap versi/perangkat.
Layanan tidak membuka aplikasi atau menyalakan mikrofon saat dihubungkan setelah
restart. Saat layar terkunci, permintaan pintasan diabaikan; buka kunci lalu
tekan tombol Aksesibilitas lagi. Jika aplikasi dihentikan paksa atau layanan
dinonaktifkan, pintasan tidak dapat memulainya.

Accessibility Service Android ditujukan untuk fungsi bantu aksesibilitas.
Sebelum distribusi, tinjau kebijakan platform yang berlaku dan sediakan
pengungkapan/persetujuan yang diwajibkan toko aplikasi.

Di Home, pemicu pintasan menggunakan controller suara yang sama dengan area
sentuh. Aplikasi menunggu Home siap dan foreground, tidak memulai sesi baru
ketika interaksi sedang berlangsung, lalu memakai alur konfirmasi TTS dan STT
yang ada. Izin mikrofon diminta melalui dialog Android saat dibutuhkan; jika
ditolak, Home menampilkan tautan ke pengaturan izin aplikasi.

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

Pada 20 November 2026:

- `flutter analyze` — tidak menemukan masalah.
- `flutter test` — 263 tes lulus, termasuk pengujian alur suara berurutan dan
  pintasan melalui fake platform channel.
- `flutter build apk --debug` — berhasil.

Pintasan, tombol Accessibility Button, dialog izin mikrofon, pembatasan
background launch, layar terkunci, dan kondisi setelah reboot belum diuji pada
perangkat fisik. Hasil build dan tes otomatis bukan pengganti validasi pada
perangkat Android; kompatibilitas OEM dan keputusan Android untuk membuka
Activity perlu diverifikasi langsung.

/// Menyediakan konstanta teks global aplikasi DailyBrief.
class AppStrings {
  AppStrings._();

  /// Menyimpan nama aplikasi.
  static const String appName = 'DailyBrief';

  /// Menyimpan sapaan saat halaman Home pertama kali ditampilkan.
  static const String welcomeGreeting =
      'Selamat datang di DailyBrief. Temukan Informasi dalam Satu Sentuhan.';

  /// Menyimpan konfirmasi suara sebelum pengenalan ucapan dimulai.
  static const String voiceConfirmation = 'Silakan berbicara.';

  /// Menyimpan label status interaksi awal.
  static const String statusReady = 'Siap Digunakan';

  /// Menyimpan label status saat aplikasi membacakan konfirmasi.
  static const String statusConfirming = 'Mengonfirmasi';

  /// Menyimpan judul area interaksi utama.
  static const String touchAreaTitle = 'Area Sentuh Utama';

  /// Menyimpan petunjuk penggunaan area interaksi utama.
  static const String touchAreaSubtitle =
      'Sentuh di mana saja pada area ini untuk mulai berbicara';

  /// Menyimpan ringkasan kategori perintah suara yang didukung.
  static const String commandHints =
      'Perintah suara: Hari · Tanggal · Jam · Cuaca · Lokasi';

  /// Menyimpan tooltip untuk membuka informasi sumber data.
  static const String dataSourcesTooltip = 'Info sumber data';

  /// Menyimpan atribusi penyedia data cuaca dan geocoding.
  static const String dataSourcesAttribution =
      'Sumber cuaca: Open-Meteo (CC BY 4.0). '
      'Lokasi: © OpenStreetMap contributors.';
}

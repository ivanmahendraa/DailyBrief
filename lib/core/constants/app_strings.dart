/// Konstanta teks global aplikasi DailyBrief.
class AppStrings {
  AppStrings._();

  /// Nama aplikasi (TASK-12).
  static const String appName = 'DailyBrief';

  /// Sapaan suara kunjungan pertama pada Splash Screen (FR-02, TASK-21).
  static const String firstVisitGreeting = 'Selamat datang di DailyBrief.';

  /// Sapaan suara kunjungan berikutnya pada Splash Screen (FR-02, TASK-23).
  static const String returningVisitGreeting =
      'Selamat datang kembali di DailyBrief.';

  /// Pesan suara pengantar setelah Home Screen terbuka.
  static const String homeGreeting = 'Temukan informasi dalam satu sentuhan.';

  /// Status interaksi awal (FR-03, TASK-12).
  static const String statusReady = 'Siap Digunakan';

  /// Judul area interaksi utama (TASK-12).
  static const String touchAreaTitle = 'Area Sentuh Utama';

  /// Petunjuk area interaksi utama (TASK-12).
  static const String touchAreaSubtitle =
      'Sentuh di mana saja pada area ini untuk mulai berbicara';

  /// Contoh perintah suara yang didukung (FR-05, TASK-12).
  static const String commandHints =
      'Perintah suara: Hari · Tanggal · Jam · Cuaca · Lokasi';
}

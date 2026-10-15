/// Konstanta teks global aplikasi DailyBrief.
class AppStrings {
  AppStrings._();

  /// Nama aplikasi (TASK-12).
  static const String appName = 'DailyBrief';

  /// Sapaan singkat pada Splash Screen setiap kali aplikasi dibuka.
  static const String splashGreeting =
      'Selamat datang di DailyBrief. Sentuh area utama untuk mulai berinteraksi dengan aplikasi.';

  /// Konfirmasi suara sebelum pengenalan ucapan dimulai.
  static const String voiceConfirmation = 'Silakan berbicara.';

  /// Status interaksi awal (FR-03, TASK-12).
  static const String statusReady = 'Siap Digunakan';

  /// Status ketika aplikasi membacakan konfirmasi sebelum mendengarkan.
  static const String statusConfirming = 'Mengonfirmasi';

  /// Judul area interaksi utama (TASK-12).
  static const String touchAreaTitle = 'Area Sentuh Utama';

  /// Petunjuk area interaksi utama (TASK-12).
  static const String touchAreaSubtitle =
      'Sentuh di mana saja pada area ini untuk mulai berbicara';

  /// Contoh perintah suara yang didukung (FR-05, TASK-12).
  static const String commandHints =
      'Perintah suara: Hari · Tanggal · Jam · Cuaca · Lokasi';
}

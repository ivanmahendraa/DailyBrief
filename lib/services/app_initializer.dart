import 'package:flutter/foundation.dart';

/// Menentukan status proses inisialisasi aplikasi.
enum InitializationStatus {
  initial,
  loading,
  success,
  failure,
}

/// Menyimpan status inisialisasi dan pesan kegagalan jika tersedia.
class InitializationResult {
  final InitializationStatus status;
  final String? errorMessage;

  const InitializationResult._({
    required this.status,
    this.errorMessage,
  });

  factory InitializationResult.success() =>
      const InitializationResult._(status: InitializationStatus.success);

  factory InitializationResult.failure(String message) =>
      InitializationResult._(
        status: InitializationStatus.failure,
        errorMessage: message,
      );

  bool get isSuccess => status == InitializationStatus.success;
  bool get isFailure => status == InitializationStatus.failure;
}

/// Menjalankan tahap inisialisasi aplikasi sebelum halaman utama dibuka.
class AppInitializer {
  const AppInitializer();

  /// Menjalankan inisialisasi layanan inti aplikasi.
  ///
  /// # Returns
  ///
  /// Mengembalikan [InitializationResult] yang menunjukkan keberhasilan atau kegagalan.
  Future<InitializationResult> initialize() async {
    try {
      await _initializeCoreServices();
      return InitializationResult.success();
    } catch (error, stackTrace) {
      debugPrint('Initialization error: $error\n$stackTrace');
      return InitializationResult.failure(
        'Gagal menyiapkan aplikasi. Sentuh coba lagi untuk mengulang.',
      );
    }
  }

  /// Menyediakan titik untuk menambahkan penyiapan layanan inti aplikasi.
  Future<void> _initializeCoreServices() async {
    // Titik penyiapan layanan dasar awal.
  }
}

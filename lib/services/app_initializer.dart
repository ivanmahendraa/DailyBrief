import 'package:flutter/foundation.dart';

/// Status eksekusi proses inisialisasi aplikasi.
enum InitializationStatus {
  initial,
  loading,
  success,
  failure,
}

/// Representasi hasil dari inisialisasi aplikasi.
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

/// Service untuk menangani inisialisasi komponen dasar sebelum halaman utama dibuka.
///
/// Memenuhi kebutuhan TASK-09 dan FR-01 pada PRD.md.
class AppInitializer {
  const AppInitializer();

  /// Menjalankan inisialisasi layanan dasar.
  ///
  /// Mengembalikan [InitializationResult] yang menandakan apakah inisialisasi
  /// berhasil atau gagal beserta pesan kesalahannya.
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

  /// Mempersiapkan layanan dasar awal.
  ///
  /// Dirancang ringan dan tidak memperlambat startup lebih lama dari yang dibutuhkan (PRD NFR-03).
  Future<void> _initializeCoreServices() async {
    // Titik penyiapan layanan dasar awal.
  }
}

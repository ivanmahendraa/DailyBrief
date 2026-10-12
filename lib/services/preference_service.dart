import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk mengelola penyimpanan preferensi lokal aplikasi DailyBrief.
///
/// Bertanggung jawab atas:
/// - Penyimpanan status kunjungan pertama (FR-02, TASK-22).
/// - Pembedaan sapaan kunjungan pertama vs berulang (TASK-23).
/// - Mendukung pengujian unit dan widget melalui injeksi [SharedPreferences] atau mock.
class PreferenceService {
  /// Kunci preferensi untuk menandai apakah sapaan kunjungan pertama telah berhasil diselesaikan.
  static const String keyFirstVisitCompleted = 'first_visit_completed';

  final SharedPreferences? _prefs;

  PreferenceService([this._prefs]);

  /// Mendapatkan instance [SharedPreferences].
  Future<SharedPreferences> _getInstance() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Memeriksa apakah ini merupakan kunjungan pertama pengguna.
  ///
  /// Mengembalikan `true` jika pengguna belum pernah menyelesaikan sapaan pertama secara utuh.
  Future<bool> isFirstVisit() async {
    try {
      final prefs = await _getInstance();
      final isCompleted = prefs.getBool(keyFirstVisitCompleted) ?? false;
      return !isCompleted;
    } catch (error) {
      debugPrint('PreferenceService.isFirstVisit error: $error');
      // Jika terjadi kesalahan pembacaan, default ke true agar panduan tetap diberikan
      return true;
    }
  }

  /// Menandai bahwa sapaan kunjungan pertama telah berhasil diselesaikan secara utuh (FR-02).
  Future<bool> markFirstVisitCompleted() async {
    try {
      final prefs = await _getInstance();
      return await prefs.setBool(keyFirstVisitCompleted, true);
    } catch (error) {
      debugPrint('PreferenceService.markFirstVisitCompleted error: $error');
      return false;
    }
  }

  /// Mengatur ulang status kunjungan (berguna untuk pengujian atau pengaturan ulang data).
  Future<bool> resetFirstVisit() async {
    try {
      final prefs = await _getInstance();
      return await prefs.remove(keyFirstVisitCompleted);
    } catch (error) {
      debugPrint('PreferenceService.resetFirstVisit error: $error');
      return false;
    }
  }
}

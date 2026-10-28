import 'package:flutter/foundation.dart';
import 'package:daily_brief/models/weather_data.dart';

/// Komponen pembuat (generator) kalimat respons cuaca dalam Bahasa Indonesia
/// yang natural dan siap dibacakan oleh Text-to-Speech (TTS).
///
/// Memenuhi kebutuhan TASK-53 dan FR-10 pada PRD.md:
/// - Mengubah data [WeatherData] menjadi kalimat verbal yang ramah pengguna.
/// - Menyertakan nama lokasi perangkat jika tersedia.
/// - Menyertakan deskripsi kondisi cuaca.
/// - Menyertakan suhu dalam satuan Celsius dengan pembulatan integer.
/// - Tidak memakai nama lokasi yang berasal dari layanan cuaca.
@immutable
class WeatherResponseGenerator {
  const WeatherResponseGenerator();

  /// Metode statis pembantu untuk pemformatan langsung tanpa instansiasi.
  static String format(WeatherData weather, {String? locationName}) =>
      const WeatherResponseGenerator().generate(
        weather,
        locationName: locationName,
      );

  /// Menghasilkan kalimat respons cuaca dari objek [WeatherData].
  String generate(WeatherData weather, {String? locationName}) {
    final speechLocation = locationName?.trim();
    final rawDesc = weather.description.trim();
    final description =
        rawDesc.isNotEmpty ? rawDesc.toLowerCase() : 'tidak diketahui';
    final temp = weather.roundedTemperature;

    if (speechLocation != null && speechLocation.isNotEmpty) {
      return 'Cuaca di $speechLocation saat ini $description dengan suhu $temp derajat Celsius.';
    }

    return 'Cuaca saat ini $description dengan suhu $temp derajat Celsius.';
  }

  /// Alias dari method [generate] untuk fleksibilitas pemanggilan.
  String generateResponse(WeatherData weather, {String? locationName}) =>
      generate(weather, locationName: locationName);
}

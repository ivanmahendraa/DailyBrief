import 'package:flutter/foundation.dart';
import 'package:daily_brief/models/weather_data.dart';

/// Komponen pembuat (generator) kalimat respons cuaca dalam Bahasa Indonesia
/// yang natural dan siap dibacakan oleh Text-to-Speech (TTS).
///
/// Memenuhi kebutuhan TASK-53 dan FR-10 pada PRD.md:
/// - Mengubah data [WeatherData] menjadi kalimat verbal yang ramah pengguna.
/// - Menyertakan nama kota jika tersedia.
/// - Menyertakan deskripsi kondisi cuaca.
/// - Menyertakan suhu dalam satuan Celsius dengan pembulatan integer.
/// - Menghasilkan kalimat yang tetap masuk akal jika [cityName] bernilai null atau kosong.
@immutable
class WeatherResponseGenerator {
  const WeatherResponseGenerator();

  /// Metode statis pembantu untuk pemformatan langsung tanpa instansiasi.
  static String format(WeatherData weather) =>
      const WeatherResponseGenerator().generate(weather);

  /// Menghasilkan kalimat respons cuaca dari objek [WeatherData].
  String generate(WeatherData weather) {
    final cityName = weather.cityName?.trim();
    final rawDesc = weather.description.trim();
    final description =
        rawDesc.isNotEmpty ? rawDesc.toLowerCase() : 'tidak diketahui';
    final temp = weather.roundedTemperature;

    if (cityName != null && cityName.isNotEmpty) {
      return 'Cuaca di $cityName saat ini $description dengan suhu $temp derajat Celsius.';
    }

    return 'Cuaca saat ini $description dengan suhu $temp derajat Celsius.';
  }

  /// Alias dari method [generate] untuk fleksibilitas pemanggilan.
  String generateResponse(WeatherData weather) => generate(weather);
}

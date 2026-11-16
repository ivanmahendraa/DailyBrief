import 'package:flutter/foundation.dart';
import 'package:daily_brief/models/weather_data.dart';
import 'package:daily_brief/services/date_time_service.dart';

/// Membuat kalimat respons cuaca berbahasa Indonesia untuk dibacakan melalui TTS.
///
/// Menyusun kalimat dari [WeatherData] dengan aturan berikut:
/// - Menggunakan nama lokasi yang diberikan jika tersedia.
/// - Menyertakan deskripsi kondisi cuaca.
/// - Menampilkan suhu saat ini atau rentang suhu harian dalam Celsius.
/// - Menghindari nama lokasi yang berasal dari data cuaca.
@immutable
class WeatherResponseGenerator {
  const WeatherResponseGenerator();

  /// Memformat respons cuaca tanpa membuat instance [WeatherResponseGenerator].
  static String format(
    WeatherData weather, {
    String? locationName,
    String? specificQuestion,
  }) => const WeatherResponseGenerator().generate(
    weather,
    locationName: locationName,
    specificQuestion: specificQuestion,
  );

  /// Menyusun respons verbal berdasarkan data cuaca dan lokasi opsional.
  String generate(
    WeatherData weather, {
    String? locationName,
    String? specificQuestion,
  }) {
    final speechLocation = locationName?.trim();
    final rawDesc = weather.description.trim();
    final description = rawDesc.isNotEmpty
        ? rawDesc.toLowerCase()
        : 'tidak diketahui';
    final temp = weather.roundedTemperature;

    final date = weather.forecastDate;
    final timePhrase = date == null
        ? 'saat ini'
        : 'pada ${DateTimeService.formatDate(date)}';
    final temperaturePhrase =
        weather.minimumTemperature != null && weather.maximumTemperature != null
        ? 'suhu berkisar antara '
              '${weather.minimumTemperature!.round()} hingga '
              '${weather.maximumTemperature!.round()} derajat Celsius'
        : 'suhu $temp derajat Celsius';
    final rainPhrase =
        specificQuestion == 'hujan' && weather.weatherCode != null
        ? _isRainCode(weather.weatherCode!)
              ? 'Ada kemungkinan hujan'
              : 'Hujan tidak diprakirakan'
        : null;

    if (rainPhrase != null) {
      final locationPhrase = speechLocation != null && speechLocation.isNotEmpty
          ? 'di $speechLocation '
          : '';
      return 'Cuaca $locationPhrase$timePhrase: $rainPhrase; '
          'kondisi $description, dengan $temperaturePhrase.';
    }

    if (speechLocation != null && speechLocation.isNotEmpty) {
      return 'Cuaca di $speechLocation $timePhrase $description dengan $temperaturePhrase.';
    }

    return 'Cuaca $timePhrase $description dengan $temperaturePhrase.';
  }

  /// Menyediakan alias [generate] untuk menghasilkan respons cuaca.
  String generateResponse(WeatherData weather, {String? locationName}) =>
      generate(weather, locationName: locationName);

  bool _isRainCode(int code) =>
      code >= 51 && code <= 67 ||
      code >= 80 && code <= 82 ||
      code >= 95 && code <= 99;
}

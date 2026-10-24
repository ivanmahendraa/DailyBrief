import 'package:flutter/foundation.dart';

/// Model data yang merepresentasikan informasi cuaca terkini dari OpenWeatherMap.
///
/// Memenuhi kebutuhan TASK-52 dan FR-10 pada PRD.md:
/// Menyimpan deskripsi cuaca, temperatur, nama kota/wilayah, serta koordinat observasi.
@immutable
class WeatherData {
  /// Kondisi atau deskripsi cuaca dalam bahasa Indonesia (misal: "berawan", "hujan ringan").
  final String description;

  /// Temperatur saat ini dalam derajat Celsius (units=metric).
  final double temperature;

  /// Nama kota atau wilayah observasi jika tersedia dari API (misal: "Batam").
  final String? cityName;

  /// Latitude koordinat observasi dari API.
  final double? latitude;

  /// Longitude koordinat observasi dari API.
  final double? longitude;

  const WeatherData({
    required this.description,
    required this.temperature,
    this.cityName,
    this.latitude,
    this.longitude,
  });

  /// Temperatur yang dibulatkan ke bilangan bulat terdekat untuk kemudahan pembacaan.
  int get roundedTemperature => temperature.round();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherData &&
        other.description == description &&
        other.temperature == temperature &&
        other.cityName == cityName &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(
        description,
        temperature,
        cityName,
        latitude,
        longitude,
      );

  @override
  String toString() =>
      'WeatherData(description: $description, temperature: $temperature°C, cityName: $cityName, lat: $latitude, lon: $longitude)';
}

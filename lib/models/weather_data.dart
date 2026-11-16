import 'package:flutter/foundation.dart';

/// Menyimpan kondisi dan suhu cuaca yang diterima dari Open-Meteo.
///
/// Data dapat mewakili kondisi terkini atau prakiraan harian.
@immutable
class WeatherData {
  /// Menyimpan deskripsi kondisi cuaca dalam bahasa Indonesia.
  final String description;

  /// Menyimpan suhu dalam derajat Celsius.
  final double temperature;

  /// Menyimpan nama kota atau wilayah jika tersedia dari API.
  final String? cityName;

  /// Menyimpan lintang koordinat observasi dari API.
  final double? latitude;

  /// Menyimpan bujur koordinat observasi dari API.
  final double? longitude;

  /// Menyimpan tanggal lokal prakiraan harian, atau `null` untuk kondisi terkini.
  final DateTime? forecastDate;

  /// Menyimpan suhu minimum harian jika data prakiraan tersedia.
  final double? minimumTemperature;

  /// Menyimpan suhu maksimum harian jika data prakiraan tersedia.
  final double? maximumTemperature;

  /// Menyimpan kode cuaca WMO dari Open-Meteo.
  final int? weatherCode;

  const WeatherData({
    required this.description,
    required this.temperature,
    this.cityName,
    this.latitude,
    this.longitude,
    this.forecastDate,
    this.minimumTemperature,
    this.maximumTemperature,
    this.weatherCode,
  });

  /// Membulatkan suhu ke bilangan bulat terdekat untuk memudahkan pembacaan.
  int get roundedTemperature => temperature.round();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherData &&
        other.description == description &&
        other.temperature == temperature &&
        other.cityName == cityName &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.forecastDate == forecastDate &&
        other.minimumTemperature == minimumTemperature &&
        other.maximumTemperature == maximumTemperature &&
        other.weatherCode == weatherCode;
  }

  @override
  int get hashCode => Object.hash(
    description,
    temperature,
    cityName,
    latitude,
    longitude,
    forecastDate,
    minimumTemperature,
    maximumTemperature,
    weatherCode,
  );

  @override
  String toString() =>
      'WeatherData(description: $description, temperature: $temperature°C, cityName: $cityName, lat: $latitude, lon: $longitude)';
}

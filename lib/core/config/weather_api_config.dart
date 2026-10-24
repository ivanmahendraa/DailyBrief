import 'package:flutter/foundation.dart';

/// Pesan standar terkait konfigurasi API cuaca.
class WeatherApiMessages {
  const WeatherApiMessages._();

  static const String unconfigured =
      'Layanan cuaca belum dikonfigurasi dengan API key.';
}

/// Konfigurasi endpoint dan API key untuk layanan cuaca OpenWeatherMap.
///
/// Memenuhi kebutuhan TASK-51 dan FR-10 pada PRD.md:
/// - API key tidak di-hardcode ke dalam kode sumber.
/// - Mendukung injeksi via constructor atau environment variable compile-time
///   (--dart-define=OPENWEATHER_API_KEY=... atau --dart-define-from-file=.env).
/// - Menyediakan endpoint OpenWeatherMap: `https://api.openweathermap.org/data/2.5/weather`.
/// - Menyediakan parameter standar: `units=metric` dan `lang=id`.
/// - Mendeteksi kondisi `unconfigured` secara aman tanpa menyebabkan crash,
///   mengikuti pola graceful fallback seperti pada `GoogleGeocodingClient`.
@immutable
class WeatherApiConfig {
  /// Default endpoint OpenWeatherMap Current Weather Data (TASK-51).
  static const String defaultEndpoint =
      'https://api.openweathermap.org/data/2.5/weather';

  /// Satuan pengukuran suhu standar: Celsius / metric (TASK-51).
  static const String defaultUnits = 'metric';

  /// Bahasa respons standar: Bahasa Indonesia (TASK-51).
  static const String defaultLang = 'id';

  /// Nama environment variable utama untuk compile-time define.
  static const String envKey = 'OPENWEATHER_API_KEY';

  /// Nama environment variable alternatif untuk fleksibilitas kompatibilitas.
  static const String altEnvKey = 'OPENWEATHERMAP_API_KEY';

  /// Mengambil nilai API key dari environment compile-time jika disediakan.
  static const String? _compileTimeApiKey = bool.hasEnvironment(envKey)
      ? String.fromEnvironment(envKey)
      : (bool.hasEnvironment(altEnvKey)
          ? String.fromEnvironment(altEnvKey)
          : null);

  /// Endpoint URL untuk pemanggilan API cuaca.
  final String endpoint;

  /// Kunci API OpenWeatherMap. Bernilai null jika belum dikonfigurasi.
  final String? apiKey;

  /// Parameter unit pengukuran suhu (default: metric).
  final String units;

  /// Parameter bahasa output deskripsi cuaca (default: id).
  final String lang;

  /// Timeout default untuk request ke endpoint cuaca.
  final Duration timeout;

  const WeatherApiConfig({
    this.endpoint = defaultEndpoint,
    String? apiKey,
    this.units = defaultUnits,
    this.lang = defaultLang,
    this.timeout = const Duration(seconds: 10),
  }) : apiKey = apiKey ?? _compileTimeApiKey;

  /// Factory untuk membuat konfigurasi eksplisit tanpa API key (unconfigured).
  factory WeatherApiConfig.unconfigured({
    String endpoint = defaultEndpoint,
    String units = defaultUnits,
    String lang = defaultLang,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return WeatherApiConfig(
      endpoint: endpoint,
      apiKey: '',
      units: units,
      lang: lang,
      timeout: timeout,
    );
  }

  /// Menandakan apakah API key telah dikonfigurasi dengan benar (tidak null dan tidak kosong).
  bool get isConfigured => apiKey != null && apiKey!.trim().isNotEmpty;

  /// Menandakan apakah API key belum dikonfigurasi / kosong (unconfigured).
  bool get isUnconfigured => !isConfigured;

  /// Pesan status unconfigured standar yang aman disampaikan ke pengguna/TTS.
  String get unconfiguredMessage => WeatherApiMessages.unconfigured;

  /// Menghasilkan [Map] parameter query standar untuk pemanggilan API cuaca.
  ///
  /// Menyertakan `lat`, `lon`, `units`, `lang`, serta `appid` (hanya jika terkonfigurasi).
  Map<String, String> buildQueryParams({
    required double latitude,
    required double longitude,
  }) {
    final params = <String, String>{
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'units': units,
      'lang': lang,
    };

    if (isConfigured) {
      params['appid'] = apiKey!.trim();
    }

    return params;
  }

  /// Menghasilkan [Uri] lengkap untuk pemanggilan API cuaca OpenWeatherMap.
  Uri buildUri({
    required double latitude,
    required double longitude,
  }) {
    return Uri.parse(endpoint).replace(
      queryParameters: buildQueryParams(
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  /// Membuat salinan konfigurasi dengan opsi penggantian nilai tertentu.
  WeatherApiConfig copyWith({
    String? endpoint,
    String? apiKey,
    String? units,
    String? lang,
    Duration? timeout,
  }) {
    return WeatherApiConfig(
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      units: units ?? this.units,
      lang: lang ?? this.lang,
      timeout: timeout ?? this.timeout,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherApiConfig &&
        other.endpoint == endpoint &&
        other.apiKey == apiKey &&
        other.units == units &&
        other.lang == lang &&
        other.timeout == timeout;
  }

  @override
  int get hashCode => Object.hash(endpoint, apiKey, units, lang, timeout);

  @override
  String toString() {
    // Masking API key agar tidak bocor dalam log atau debug print (NFR-05)
    final maskedKey = isConfigured ? '***' : 'unconfigured';
    return 'WeatherApiConfig(endpoint: $endpoint, apiKey: $maskedKey, units: $units, lang: $lang, timeout: $timeout)';
  }
}

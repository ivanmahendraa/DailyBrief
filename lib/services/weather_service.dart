import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:daily_brief/core/config/weather_api_config.dart';
import 'package:daily_brief/models/weather_data.dart';

export 'package:daily_brief/models/weather_data.dart';

/// Pesan standar terkait layanan informasi cuaca.
class WeatherMessages {
  const WeatherMessages._();

  static const String success = 'Informasi cuaca berhasil ditemukan.';
  static const String unconfigured = WeatherApiMessages.unconfigured;
  static const String unauthorized =
      'Kunci API cuaca tidak valid atau belum diotorisasi.';
  static const String rateLimited =
      'Batas kuota permintaan cuaca telah terlampaui. Silakan coba lagi nanti.';
  static const String notFound =
      'Informasi cuaca untuk lokasi ini tidak ditemukan.';
  static const String timeout =
      'Batas waktu koneksi ke layanan cuaca habis. Silakan coba kembali.';
  static const String networkError =
      'Gagal terhubung ke layanan cuaca. Periksa koneksi internet Anda.';
  static const String apiError = 'Terjadi kesalahan pada layanan cuaca.';
  static const String invalidFormat =
      'Format data cuaca yang diterima tidak valid.';
  static const String failure =
      'Terjadi kesalahan saat memproses informasi cuaca.';
}

/// Status hasil pemanggilan layanan cuaca.
enum WeatherStatus {
  success,
  unconfigured,
  unauthorized,
  rateLimited,
  notFound,
  timeout,
  networkError,
  apiError,
  failure,
}

/// Representasi hasil dari pemanggilan layanan cuaca.
@immutable
class WeatherResult {
  final WeatherStatus status;
  final WeatherData? data;
  final String message;

  const WeatherResult({
    required this.status,
    this.data,
    required this.message,
  });

  factory WeatherResult.success(WeatherData data, [String? message]) =>
      WeatherResult(
        status: WeatherStatus.success,
        data: data,
        message: message ?? WeatherMessages.success,
      );

  factory WeatherResult.unconfigured([String? message]) => WeatherResult(
        status: WeatherStatus.unconfigured,
        message: message ?? WeatherMessages.unconfigured,
      );

  factory WeatherResult.unauthorized([String? message]) => WeatherResult(
        status: WeatherStatus.unauthorized,
        message: message ?? WeatherMessages.unauthorized,
      );

  factory WeatherResult.rateLimited([String? message]) => WeatherResult(
        status: WeatherStatus.rateLimited,
        message: message ?? WeatherMessages.rateLimited,
      );

  factory WeatherResult.notFound([String? message]) => WeatherResult(
        status: WeatherStatus.notFound,
        message: message ?? WeatherMessages.notFound,
      );

  factory WeatherResult.timeout([String? message]) => WeatherResult(
        status: WeatherStatus.timeout,
        message: message ?? WeatherMessages.timeout,
      );

  factory WeatherResult.networkError([String? message]) => WeatherResult(
        status: WeatherStatus.networkError,
        message: message ?? WeatherMessages.networkError,
      );

  factory WeatherResult.apiError([String? message]) => WeatherResult(
        status: WeatherStatus.apiError,
        message: message ?? WeatherMessages.apiError,
      );

  factory WeatherResult.failure(String message) => WeatherResult(
        status: WeatherStatus.failure,
        message: message,
      );

  bool get isSuccess => status == WeatherStatus.success;
  bool get isUnconfigured => status == WeatherStatus.unconfigured;
  bool get isUnauthorized => status == WeatherStatus.unauthorized;
  bool get isRateLimited => status == WeatherStatus.rateLimited;
  bool get isNotFound => status == WeatherStatus.notFound;
  bool get isTimeout => status == WeatherStatus.timeout;
  bool get isNetworkError => status == WeatherStatus.networkError;
  bool get isApiError => status == WeatherStatus.apiError;
  bool get isFailure => !isSuccess;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherResult &&
        other.status == status &&
        other.data == data &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(status, data, message);

  @override
  String toString() =>
      'WeatherResult(status: $status, data: $data, message: $message)';
}

/// Kontrak abstraksi client untuk mengambil data cuaca,
/// memungkinkan dependency injection dan pengujian modular tanpa koneksi API nyata.
abstract interface class WeatherClient {
  Future<WeatherResult> getCurrentWeather({
    required double latitude,
    required double longitude,
  });
}

/// Implementasi client cuaca menggunakan OpenWeatherMap Current Weather API (TASK-51, TASK-52).
class OpenWeatherMapClient implements WeatherClient {
  final WeatherApiConfig config;
  final HttpClient Function()? httpClientFactory;
  final Duration timeout;

  OpenWeatherMapClient({
    WeatherApiConfig? config,
    this.httpClientFactory,
    Duration? timeout,
  })  : config = config ?? const WeatherApiConfig(),
        timeout = timeout ?? config?.timeout ?? const Duration(seconds: 10);

  @override
  Future<WeatherResult> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    if (config.isUnconfigured) {
      return WeatherResult.unconfigured();
    }

    debugPrint(
      '[DIAGNOSTIC][WEATHER_LOCATION] '
      'latitude=$latitude longitude=$longitude',
    );
    final uri = config.buildUri(
      latitude: latitude,
      longitude: longitude,
    );

    final client =
        httpClientFactory != null ? httpClientFactory!() : HttpClient();

    try {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final body =
          await response.transform(utf8.decoder).join().timeout(timeout);

      if (response.statusCode == 401) {
        return WeatherResult.unauthorized();
      }
      if (response.statusCode == 429) {
        return WeatherResult.rateLimited();
      }
      if (response.statusCode == 404) {
        return WeatherResult.notFound();
      }
      if (response.statusCode != 200) {
        return WeatherResult.apiError(
          '${WeatherMessages.apiError} (HTTP ${response.statusCode})',
        );
      }

      final dynamic data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        return WeatherResult.failure(WeatherMessages.invalidFormat);
      }

      return parseOpenWeatherResponse(data);
    } on SocketException catch (e, stackTrace) {
      debugPrint('OpenWeatherMapClient socket error: $e\n$stackTrace');
      return WeatherResult.networkError();
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('OpenWeatherMapClient timeout: $e\n$stackTrace');
      return WeatherResult.timeout();
    } on FormatException catch (e, stackTrace) {
      debugPrint('OpenWeatherMapClient format error: $e\n$stackTrace');
      return WeatherResult.failure(WeatherMessages.invalidFormat);
    } catch (e, stackTrace) {
      debugPrint('OpenWeatherMapClient unexpected error: $e\n$stackTrace');
      return WeatherResult.failure('${WeatherMessages.failure}: $e');
    } finally {
      if (httpClientFactory == null) {
        client.close();
      }
    }
  }

  /// Memetakan respons JSON OpenWeatherMap ke [WeatherResult].
  static WeatherResult parseOpenWeatherResponse(Map<String, dynamic> data) {
    final cod = data['cod'];
    if (cod != null && cod != 200 && cod != '200') {
      final message = data['message'] as String?;
      return WeatherResult.apiError(
        message != null && message.isNotEmpty
            ? '${WeatherMessages.apiError}: $message'
            : '${WeatherMessages.apiError} (code: $cod)',
      );
    }

    final main = data['main'];
    if (main is! Map<String, dynamic>) {
      return WeatherResult.failure(
        '${WeatherMessages.invalidFormat}: Data temperatur utama tidak ditemukan.',
      );
    }

    final tempVal = main['temp'];
    if (tempVal is! num) {
      return WeatherResult.failure(
        '${WeatherMessages.invalidFormat}: Nilai temperatur tidak tersedia.',
      );
    }

    final weatherList = data['weather'];
    if (weatherList is! List || weatherList.isEmpty) {
      return WeatherResult.failure(
        '${WeatherMessages.invalidFormat}: Deskripsi kondisi cuaca tidak ditemukan.',
      );
    }

    final firstWeather = weatherList.first;
    if (firstWeather is! Map<String, dynamic>) {
      return WeatherResult.failure(
        '${WeatherMessages.invalidFormat}: Format data cuaca tidak valid.',
      );
    }

    final rawDescription = (firstWeather['description'] as String?)?.trim();
    final rawMain = (firstWeather['main'] as String?)?.trim();
    final description = (rawDescription != null && rawDescription.isNotEmpty)
        ? rawDescription
        : ((rawMain != null && rawMain.isNotEmpty) ? rawMain : null);

    if (description == null) {
      return WeatherResult.failure(
        '${WeatherMessages.invalidFormat}: Deskripsi cuaca kosong.',
      );
    }

    final rawCityName = (data['name'] as String?)?.trim();
    final cityName =
        (rawCityName != null && rawCityName.isNotEmpty) ? rawCityName : null;
    debugPrint(
      '[DIAGNOSTIC][WEATHER_API_RESPONSE] '
      'locationField="name" locationName="${cityName ?? ''}"',
    );

    final coord = data['coord'] as Map<String, dynamic>?;
    final lat = (coord?['lat'] as num?)?.toDouble();
    final lon = (coord?['lon'] as num?)?.toDouble();

    final weatherData = WeatherData(
      description: description,
      temperature: tempVal.toDouble(),
      cityName: cityName,
      latitude: lat,
      longitude: lon,
    );

    return WeatherResult.success(weatherData);
  }
}

/// Service untuk mengambil dan mengelola informasi cuaca terkini
/// berdasarkan koordinat latitude dan longitude.
///
/// Memenuhi kebutuhan TASK-52 dan FR-10 pada PRD.md.
class WeatherService {
  final WeatherClient _client;

  WeatherService([WeatherClient? client, WeatherApiConfig? config])
      : _client = client ?? OpenWeatherMapClient(config: config);

  /// Mengambil informasi cuaca terkini untuk koordinat [latitude] dan [longitude].
  ///
  /// Menjamin bahwa proses tidak melempar uncaught exception yang menyebabkan aplikasi crash.
  Future<WeatherResult> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      return await _client.getCurrentWeather(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e, stackTrace) {
      debugPrint('WeatherService.getCurrentWeather error: $e\n$stackTrace');
      return WeatherResult.failure('${WeatherMessages.failure}: $e');
    }
  }
}

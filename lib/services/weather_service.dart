import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:daily_brief/models/weather_data.dart';

export 'package:daily_brief/models/weather_data.dart';

/// Menyediakan pesan standar untuk hasil layanan cuaca.
class WeatherMessages {
  const WeatherMessages._();

  static const String success = 'Informasi cuaca berhasil ditemukan.';
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
  static const String forecastUnavailable =
      'Prakiraan cuaca hanya tersedia untuk tanggal hari ini hingga 16 hari ke depan.';
  static const String historicalUnavailable =
      'Data cuaca untuk tanggal tersebut belum tersedia.';
  static const String failure =
      'Terjadi kesalahan saat memproses informasi cuaca.';
}

/// Menentukan status hasil permintaan cuaca.
enum WeatherStatus {
  success,
  rateLimited,
  notFound,
  timeout,
  networkError,
  apiError,
  failure,
}

/// Menyimpan status, data, dan pesan hasil permintaan cuaca.
@immutable
class WeatherResult {
  final WeatherStatus status;
  final WeatherData? data;
  final String message;

  const WeatherResult({required this.status, this.data, required this.message});

  factory WeatherResult.success(WeatherData data, [String? message]) =>
      WeatherResult(
        status: WeatherStatus.success,
        data: data,
        message: message ?? WeatherMessages.success,
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

  factory WeatherResult.failure(String message) =>
      WeatherResult(status: WeatherStatus.failure, message: message);

  bool get isSuccess => status == WeatherStatus.success;
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

/// Mendefinisikan kontrak client untuk mengambil kondisi cuaca terkini.
abstract interface class WeatherClient {
  Future<WeatherResult> getCurrentWeather({
    required double latitude,
    required double longitude,
  });
}

abstract interface class DateWeatherClient {
  Future<WeatherResult> getWeatherForDate({
    required double latitude,
    required double longitude,
    required DateTime date,
  });
}

/// Mengambil kondisi dan data cuaca harian melalui API Open-Meteo.
class OpenMeteoClient implements WeatherClient, DateWeatherClient {
  static const String defaultEndpoint =
      'https://api.open-meteo.com/v1/forecast';
  static const String defaultArchiveEndpoint =
      'https://archive-api.open-meteo.com/v1/archive';
  static const String currentVariables = 'temperature_2m,weather_code';
  static const String dailyVariables =
      'weather_code,temperature_2m_min,temperature_2m_max';
  static const int maxForecastDays = 16;
  static const int maxRecentPastDays = 7;

  final String endpoint;
  final String archiveEndpoint;
  final HttpClient Function()? httpClientFactory;
  final Duration timeout;
  final DateTime Function() _now;

  OpenMeteoClient({
    this.endpoint = defaultEndpoint,
    this.archiveEndpoint = defaultArchiveEndpoint,
    this.httpClientFactory,
    this.timeout = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<WeatherResult> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': currentVariables,
        'temperature_unit': 'celsius',
        'timezone': 'auto',
      },
    );
    return _request(uri, parseOpenMeteoResponse);
  }

  @override
  Future<WeatherResult> getWeatherForDate({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    final requestedDate = DateTime(date.year, date.month, date.day);
    final todayTime = _now();
    final today = DateTime(todayTime.year, todayTime.month, todayTime.day);
    final daysAhead = requestedDate.difference(today).inDays;
    if (daysAhead == 0) {
      return getCurrentWeather(latitude: latitude, longitude: longitude);
    }
    if (daysAhead > maxForecastDays) {
      return WeatherResult.notFound(WeatherMessages.forecastUnavailable);
    }

    final daysAgo = -daysAhead;
    if (daysAgo > 0 && daysAgo <= maxRecentPastDays) {
      final uri = Uri.parse(endpoint).replace(
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'daily': dailyVariables,
          'past_days': daysAgo.toString(),
          'temperature_unit': 'celsius',
          'timezone': 'auto',
        },
      );
      return _request(
        uri,
        (data) => parseOpenMeteoDailyResponse(data, requestedDate),
      );
    }

    final targetEndpoint = requestedDate.isBefore(today)
        ? archiveEndpoint
        : endpoint;
    final dateText =
        '${requestedDate.year.toString().padLeft(4, '0')}-'
        '${requestedDate.month.toString().padLeft(2, '0')}-'
        '${requestedDate.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse(targetEndpoint).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'daily': dailyVariables,
        'start_date': dateText,
        'end_date': dateText,
        'temperature_unit': 'celsius',
        'timezone': 'auto',
      },
    );
    return _request(
      uri,
      (data) => parseOpenMeteoDailyResponse(data, requestedDate),
    );
  }

  Future<WeatherResult> _request(
    Uri uri,
    WeatherResult Function(Map<String, dynamic>) parseResponse,
  ) async {
    final client = httpClientFactory != null
        ? httpClientFactory!()
        : HttpClient();

    try {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);

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

      return parseResponse(data);
    } on SocketException catch (e, stackTrace) {
      debugPrint('OpenMeteoClient socket error: $e\n$stackTrace');
      return WeatherResult.networkError();
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('OpenMeteoClient timeout: $e\n$stackTrace');
      return WeatherResult.timeout();
    } on FormatException catch (e, stackTrace) {
      debugPrint('OpenMeteoClient format error: $e\n$stackTrace');
      return WeatherResult.failure(WeatherMessages.invalidFormat);
    } catch (e, stackTrace) {
      debugPrint('OpenMeteoClient unexpected error: $e\n$stackTrace');
      return WeatherResult.failure('${WeatherMessages.failure}: $e');
    } finally {
      if (httpClientFactory == null) {
        client.close();
      }
    }
  }

  /// Memetakan respons kondisi terkini Open-Meteo ke [WeatherResult].
  static WeatherResult parseOpenMeteoResponse(Map<String, dynamic> data) {
    final current = data['current'];
    if (current is! Map<String, dynamic>) {
      return WeatherResult.failure(WeatherMessages.invalidFormat);
    }
    final temperature = current['temperature_2m'];
    final weatherCode = current['weather_code'];
    if (temperature is! num || weatherCode is! num) {
      return WeatherResult.failure(WeatherMessages.invalidFormat);
    }

    return WeatherResult.success(
      WeatherData(
        description: _descriptionForWeatherCode(weatherCode.toInt()),
        temperature: temperature.toDouble(),
        weatherCode: weatherCode.toInt(),
      ),
    );
  }

  static WeatherResult parseOpenMeteoDailyResponse(
    Map<String, dynamic> data,
    DateTime requestedDate,
  ) {
    final daily = data['daily'];
    if (daily is! Map<String, dynamic>) {
      return WeatherResult.notFound(WeatherMessages.historicalUnavailable);
    }

    final times = daily['time'];
    final codes = daily['weather_code'];
    final minimums = daily['temperature_2m_min'];
    final maximums = daily['temperature_2m_max'];
    if (times is! List ||
        codes is! List ||
        minimums is! List ||
        maximums is! List) {
      return WeatherResult.failure(WeatherMessages.invalidFormat);
    }

    final requestedDateText =
        '${requestedDate.year.toString().padLeft(4, '0')}-'
        '${requestedDate.month.toString().padLeft(2, '0')}-'
        '${requestedDate.day.toString().padLeft(2, '0')}';
    final index = times.indexOf(requestedDateText);
    if (index < 0 ||
        index >= codes.length ||
        index >= minimums.length ||
        index >= maximums.length) {
      return WeatherResult.notFound(WeatherMessages.historicalUnavailable);
    }

    final code = codes[index];
    final minimum = minimums[index];
    final maximum = maximums[index];
    if (code is! num || minimum is! num || maximum is! num) {
      return WeatherResult.notFound(WeatherMessages.historicalUnavailable);
    }

    return WeatherResult.success(
      WeatherData(
        description: _descriptionForWeatherCode(code.toInt()),
        temperature: (minimum.toDouble() + maximum.toDouble()) / 2,
        forecastDate: requestedDate,
        minimumTemperature: minimum.toDouble(),
        maximumTemperature: maximum.toDouble(),
        weatherCode: code.toInt(),
      ),
    );
  }

  static String _descriptionForWeatherCode(int code) => switch (code) {
    0 => 'cerah',
    1 => 'sebagian besar cerah',
    2 => 'cerah berawan',
    3 => 'berawan',
    45 || 48 => 'berkabut',
    51 || 53 || 55 => 'gerimis',
    56 || 57 => 'gerimis beku',
    61 => 'hujan ringan',
    63 => 'hujan sedang',
    65 => 'hujan lebat',
    66 || 67 => 'hujan beku',
    71 => 'salju ringan',
    73 => 'salju sedang',
    75 => 'salju lebat',
    77 => 'butiran salju',
    80 => 'hujan ringan',
    81 => 'hujan sedang',
    82 => 'hujan lebat',
    85 || 86 => 'hujan salju',
    95 => 'hujan disertai petir',
    96 => 'hujan disertai petir dan hujan es ringan',
    99 => 'hujan disertai petir dan hujan es lebat',
    _ => 'kondisi cuaca tidak diketahui',
  };
}

/// Mengelola permintaan cuaca berdasarkan koordinat geografis.
///
class WeatherService {
  final WeatherClient _client;

  WeatherService([WeatherClient? client])
    : _client = client ?? OpenMeteoClient();

  /// Mengambil kondisi cuaca terkini pada koordinat [latitude] dan [longitude].
  ///
  /// Mengembalikan [WeatherResult] tanpa meneruskan exception dari client.
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

  Future<WeatherResult> getWeatherForDate({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    final client = _client;
    if (client is! DateWeatherClient) {
      return WeatherResult.failure(
        'Client cuaca tidak mendukung prakiraan tanggal.',
      );
    }

    try {
      return await (client as DateWeatherClient).getWeatherForDate(
        latitude: latitude,
        longitude: longitude,
        date: date,
      );
    } catch (error, stackTrace) {
      debugPrint('WeatherService.getWeatherForDate error: $error\n$stackTrace');
      return WeatherResult.failure('${WeatherMessages.failure}: $error');
    }
  }
}

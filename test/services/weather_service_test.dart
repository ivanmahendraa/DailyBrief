import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/services/weather_service.dart';

class _FakeWeatherClient implements WeatherClient {
  double? lastLatitude;
  double? lastLongitude;
  int callCount = 0;
  bool throwException = false;

  @override
  Future<WeatherResult> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    callCount++;
    lastLatitude = latitude;
    lastLongitude = longitude;
    if (throwException) throw StateError('WeatherClient failed');
    return WeatherResult.success(
      const WeatherData(description: 'cerah', temperature: 30),
    );
  }
}

class _FakeHttpClient extends Fake implements HttpClient {
  Uri? lastUri;
  @override
  String? userAgent;
  int statusCode = 200;
  String responseBody = '{}';
  Object? requestError;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    lastUri = url;
    if (requestError case final error?) throw error;
    return _FakeHttpClientRequest(statusCode, responseBody);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final int statusCode;
  final String responseBody;

  _FakeHttpClientRequest(this.statusCode, this.responseBody);

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpClientResponse(statusCode, responseBody);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    with Fake
    implements HttpClientResponse {
  @override
  final int statusCode;
  final String body;

  _FakeHttpClientResponse(this.statusCode, this.body);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(utf8.encode(body)).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

void main() {
  group('WeatherService', () {
    test('passes device coordinates to the weather client', () async {
      final client = _FakeWeatherClient();
      final service = WeatherService(client);

      final result = await service.getCurrentWeather(
        latitude: 1.1301,
        longitude: 104.0529,
      );

      expect(client.callCount, 1);
      expect(client.lastLatitude, 1.1301);
      expect(client.lastLongitude, 104.0529);
      expect(result.isSuccess, isTrue);
    });

    test(
      'converts an unexpected client exception to a failure result',
      () async {
        final client = _FakeWeatherClient()..throwException = true;
        final result = await WeatherService(client)
            .getCurrentWeather(latitude: 1, longitude: 104);

        expect(result.isFailure, isTrue);
        expect(result.message, contains(WeatherMessages.failure));
      },
    );
  });

  group('OpenMeteoClient', () {
    late _FakeHttpClient httpClient;
    late OpenMeteoClient client;

    setUp(() {
      httpClient = _FakeHttpClient();
      client = OpenMeteoClient(
        httpClientFactory: () => httpClient,
        now: () => DateTime(2026, 11, 16, 15),
      );
    });

    test('requests current weather without an API key', () async {
      httpClient.responseBody = jsonEncode({
        'current': {'temperature_2m': 30.4, 'weather_code': 2},
      });

      final result = await client.getCurrentWeather(
        latitude: -5.477,
        longitude: 118.191,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.temperature, 30.4);
      expect(result.data?.description, 'cerah berawan');
      expect(result.data?.cityName, isNull);
      expect(httpClient.lastUri?.host, 'api.open-meteo.com');
      expect(httpClient.lastUri?.path, '/v1/forecast');
      expect(httpClient.lastUri?.queryParameters['latitude'], '-5.477');
      expect(httpClient.lastUri?.queryParameters['longitude'], '118.191');
      expect(
        httpClient.lastUri?.queryParameters['current'],
        OpenMeteoClient.currentVariables,
      );
      expect(httpClient.lastUri?.queryParameters['timezone'], 'auto');
      expect(
        httpClient.lastUri?.queryParameters.containsKey('apikey'),
        isFalse,
      );
      expect(httpClient.lastUri?.queryParameters.containsKey('appid'), isFalse);
    });

    test('maps WMO weather codes into Indonesian descriptions', () {
      final descriptions = {
        0: 'cerah',
        2: 'cerah berawan',
        3: 'berawan',
        45: 'berkabut',
        51: 'gerimis',
        61: 'hujan ringan',
        65: 'hujan lebat',
        71: 'salju ringan',
        82: 'hujan lebat',
        95: 'hujan disertai petir',
      };

      for (final entry in descriptions.entries) {
        final result = OpenMeteoClient.parseOpenMeteoResponse({
          'current': {'temperature_2m': 27, 'weather_code': entry.key},
        });
        expect(result.data?.description, entry.value);
      }
    });

    test(
      'requests a date-specific forecast and parses daily temperature range',
      () async {
        httpClient.responseBody = jsonEncode({
          'daily': {
            'time': ['2026-11-18'],
            'weather_code': [61],
            'temperature_2m_min': [23.1],
            'temperature_2m_max': [29.8],
          },
        });

        final result = await client.getWeatherForDate(
          latitude: -6.2,
          longitude: 106.8,
          date: DateTime(2026, 11, 18),
        );

        expect(result.isSuccess, isTrue);
        expect(result.data?.forecastDate, DateTime(2026, 11, 18));
        expect(result.data?.minimumTemperature, 23.1);
        expect(result.data?.maximumTemperature, 29.8);
        expect(result.data?.weatherCode, 61);
        expect(httpClient.lastUri?.path, '/v1/forecast');
        expect(
          httpClient.lastUri?.queryParameters['daily'],
          OpenMeteoClient.dailyVariables,
        );
        expect(httpClient.lastUri?.queryParameters['start_date'], '2026-11-18');
        expect(httpClient.lastUri?.queryParameters['end_date'], '2026-11-18');
      },
    );

    test('uses Forecast API past days for yesterday', () async {
      httpClient.responseBody = jsonEncode({
        'daily': {
          'time': ['2026-11-15', '2026-11-16'],
          'weather_code': [3],
          'temperature_2m_min': [24, 25],
          'temperature_2m_max': [31, 32],
        },
      });

      final result = await client.getWeatherForDate(
        latitude: -6.2,
        longitude: 106.8,
        date: DateTime(2026, 11, 15),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.forecastDate, DateTime(2026, 11, 15));
      expect(httpClient.lastUri?.host, 'api.open-meteo.com');
      expect(httpClient.lastUri?.path, '/v1/forecast');
      expect(httpClient.lastUri?.queryParameters['past_days'], '1');
      expect(
        httpClient.lastUri?.queryParameters['daily'],
        OpenMeteoClient.dailyVariables,
      );
    });

    test('uses Archive API for dates older than recent past data', () async {
      httpClient.responseBody = jsonEncode({
        'daily': {
          'time': ['2026-11-08'],
          'weather_code': [3],
          'temperature_2m_min': [24],
          'temperature_2m_max': [31],
        },
      });

      final result = await client.getWeatherForDate(
        latitude: -6.2,
        longitude: 106.8,
        date: DateTime(2026, 11, 8),
      );

      expect(result.isSuccess, isTrue);
      expect(httpClient.lastUri?.host, 'archive-api.open-meteo.com');
      expect(httpClient.lastUri?.path, '/v1/archive');
    });

    test(
      'rejects forecast dates beyond provider range without a request',
      () async {
        final result = await client.getWeatherForDate(
          latitude: -6.2,
          longitude: 106.8,
          date: DateTime(2026, 12, 3),
        );

        expect(result.isNotFound, isTrue);
        expect(result.message, WeatherMessages.forecastUnavailable);
        expect(httpClient.lastUri, isNull);
      },
    );

    test('returns failure for missing or invalid current-weather fields', () {
      expect(OpenMeteoClient.parseOpenMeteoResponse({}).isFailure, isTrue);
      expect(
        OpenMeteoClient.parseOpenMeteoResponse({
          'current': {'temperature_2m': 'panas', 'weather_code': 1},
        }).isFailure,
        isTrue,
      );
      expect(
        OpenMeteoClient.parseOpenMeteoResponse({
          'current': {'temperature_2m': 28},
        }).isFailure,
        isTrue,
      );
    });

    test('maps HTTP rate limits and other server errors', () async {
      httpClient.statusCode = 429;
      expect(
        (await client.getCurrentWeather(
          latitude: 1,
          longitude: 104,
        )).isRateLimited,
        isTrue,
      );

      httpClient.statusCode = 500;
      final result = await client.getCurrentWeather(
        latitude: 1,
        longitude: 104,
      );
      expect(result.isApiError, isTrue);
      expect(result.message, contains('HTTP 500'));
    });

    test('maps timeout, network, and invalid JSON responses', () async {
      httpClient.requestError = TimeoutException('request timed out');
      expect(
        (await client.getCurrentWeather(latitude: 1, longitude: 104)).isTimeout,
        isTrue,
      );

      httpClient.requestError = const SocketException('offline');
      expect(
        (await client.getCurrentWeather(
          latitude: 1,
          longitude: 104,
        )).isNetworkError,
        isTrue,
      );

      httpClient
        ..requestError = null
        ..responseBody = '<html>invalid</html>';
      expect(
        (await client.getCurrentWeather(latitude: 1, longitude: 104)).isFailure,
        isTrue,
      );
    });
  });

  group('WeatherData and WeatherResult', () {
    test('weather values compare and round temperatures', () {
      const first = WeatherData(description: 'berawan', temperature: 30.5);
      const equal = WeatherData(description: 'berawan', temperature: 30.5);

      expect(first, equal);
      expect(first.roundedTemperature, 31);
    });

    test('result factories expose their relevant statuses', () {
      const data = WeatherData(description: 'cerah', temperature: 32);

      expect(WeatherResult.success(data).isSuccess, isTrue);
      expect(WeatherResult.rateLimited().isRateLimited, isTrue);
      expect(WeatherResult.notFound().isNotFound, isTrue);
      expect(WeatherResult.timeout().isTimeout, isTrue);
      expect(WeatherResult.networkError().isNetworkError, isTrue);
      expect(WeatherResult.apiError().isApiError, isTrue);
      expect(WeatherResult.failure('Gagal').isFailure, isTrue);
    });
  });
}

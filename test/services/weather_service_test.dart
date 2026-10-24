import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/core/config/weather_api_config.dart';
import 'package:daily_brief/services/weather_service.dart';

/// Fake client untuk pengujian WeatherService tanpa request HTTP.
class _FakeWeatherClient implements WeatherClient {
  double? lastLatitude;
  double? lastLongitude;
  int callCount = 0;

  WeatherResult resultToReturn = WeatherResult.success(
    const WeatherData(
      description: 'cerah berawan',
      temperature: 31.2,
      cityName: 'Batam',
      latitude: 1.1301,
      longitude: 104.0529,
    ),
  );

  bool throwException = false;
  Object? customException;

  @override
  Future<WeatherResult> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    callCount++;
    lastLatitude = latitude;
    lastLongitude = longitude;

    if (throwException) {
      if (customException != null) throw customException!;
      throw StateError('WeatherClient failed unexpectedly');
    }

    return resultToReturn;
  }
}

/// Fake HttpClient untuk menguji OpenWeatherMapClient tanpa koneksi internet.
class _FakeHttpClient extends Fake implements HttpClient {
  Uri? lastUri;
  int statusCode = 200;
  String responseBody = '{}';
  bool throwOnGetUrl = false;
  Object? getUrlException;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    lastUri = url;
    if (throwOnGetUrl) {
      if (getUrlException != null) throw getUrlException!;
      throw const SocketException('Connection failed');
    }
    return _FakeHttpClientRequest(url, statusCode, responseBody);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final Uri uri;
  final int statusCode;
  final String responseBody;

  _FakeHttpClientRequest(this.uri, this.statusCode, this.responseBody);

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse(statusCode, responseBody);
  }
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
  }) {
    return Stream<List<int>>.value(utf8.encode(body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  group('WeatherService Unit Tests (TASK-52)', () {
    late _FakeWeatherClient fakeClient;
    late WeatherService weatherService;

    setUp(() {
      fakeClient = _FakeWeatherClient();
      weatherService = WeatherService(fakeClient);
    });

    test('1. Mengambil cuaca berhasil dan meneruskan latitude/longitude ke client', () async {
      const lat = 1.1301;
      const lon = 104.0529;

      final result = await weatherService.getCurrentWeather(
        latitude: lat,
        longitude: lon,
      );

      expect(fakeClient.callCount, equals(1));
      expect(fakeClient.lastLatitude, equals(lat));
      expect(fakeClient.lastLongitude, equals(lon));
      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.description, equals('cerah berawan'));
      expect(result.data!.temperature, equals(31.2));
      expect(result.data!.roundedTemperature, equals(31));
      expect(result.data!.cityName, equals('Batam'));
    });

    test('2. Menangani exception tak terduga dari client dengan aman tanpa crash', () async {
      fakeClient.throwException = true;
      fakeClient.customException = StateError('Koneksi terputus tiba-tiba');

      final result = await weatherService.getCurrentWeather(
        latitude: 1.0,
        longitude: 104.0,
      );

      expect(result.isFailure, isTrue);
      expect(result.message, contains(WeatherMessages.failure));
    });
  });

  group('OpenWeatherMapClient Tests (TASK-52)', () {
    late _FakeHttpClient fakeHttpClient;
    late WeatherApiConfig testConfig;

    setUp(() {
      fakeHttpClient = _FakeHttpClient();
      testConfig = const WeatherApiConfig(
        apiKey: 'dummy_api_key_123',
      );
    });

    Map<String, dynamic> createValidWeatherJson({
      String description = 'berawan',
      double temp = 29.5,
      String name = 'Batam',
      double lat = 1.1301,
      double lon = 104.0529,
    }) {
      return {
        'coord': {'lon': lon, 'lat': lat},
        'weather': [
          {'id': 803, 'main': 'Clouds', 'description': description}
        ],
        'main': {'temp': temp, 'humidity': 80},
        'name': name,
        'cod': 200,
      };
    }

    test('1. Response cuaca berhasil diproses dengan benar', () async {
      final jsonMap = createValidWeatherJson(
        description: 'cerah berawan',
        temp: 30.4,
        name: 'Kota Batam',
      );
      fakeHttpClient.responseBody = jsonEncode(jsonMap);

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      final result = await client.getCurrentWeather(
        latitude: 1.1301,
        longitude: 104.0529,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.description, equals('cerah berawan'));
      expect(result.data!.temperature, equals(30.4));
      expect(result.data!.cityName, equals('Kota Batam'));
    });

    test('2. Parsing temperatur berbagai nilai (desimal, pembulatan, dan minus)', () async {
      // Positif desimal
      final jsonPos = createValidWeatherJson(temp: 29.8);
      fakeHttpClient.responseBody = jsonEncode(jsonPos);

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      final resultPos = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);
      expect(resultPos.data!.temperature, equals(29.8));
      expect(resultPos.data!.roundedTemperature, equals(30));

      // Integer temperatur
      final jsonInt = createValidWeatherJson(temp: 25.0);
      fakeHttpClient.responseBody = jsonEncode(jsonInt);
      final resultInt = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);
      expect(resultInt.data!.temperature, equals(25.0));
      expect(resultInt.data!.roundedTemperature, equals(25));

      // Minus temperatur
      final jsonMinus = createValidWeatherJson(temp: -3.4);
      fakeHttpClient.responseBody = jsonEncode(jsonMinus);
      final resultMinus = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);
      expect(resultMinus.data!.temperature, equals(-3.4));
      expect(resultMinus.data!.roundedTemperature, equals(-3));
    });

    test('3. Parsing deskripsi cuaca Bahasa Indonesia', () async {
      const descriptions = [
        'hujan ringan',
        'hujan lebat disertai petir',
        'cerah',
        'kabut tipis',
      ];

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      for (final desc in descriptions) {
        fakeHttpClient.responseBody = jsonEncode(createValidWeatherJson(description: desc));
        final result = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);
        expect(result.isSuccess, isTrue);
        expect(result.data!.description, equals(desc));
      }
    });

    test('4. API key belum dikonfigurasi (unconfigured) mengembalikan status unconfigured tanpa HTTP request', () async {
      final unconfiguredClient = OpenWeatherMapClient(
        config: WeatherApiConfig.unconfigured(),
        httpClientFactory: () => fakeHttpClient,
      );

      final result = await unconfiguredClient.getCurrentWeather(
        latitude: 1.1301,
        longitude: 104.0529,
      );

      expect(result.isUnconfigured, isTrue);
      expect(result.status, equals(WeatherStatus.unconfigured));
      expect(result.message, equals(WeatherMessages.unconfigured));
      // Memastikan HTTP client tidak dipanggil sama sekali
      expect(fakeHttpClient.lastUri, isNull);
    });

    test('5. HTTP 401 mengembalikan status unauthorized', () async {
      fakeHttpClient.statusCode = 401;
      fakeHttpClient.responseBody = jsonEncode({
        'cod': 401,
        'message': 'Invalid API key. Please see https://openweathermap.org/faq#error401 for more info.',
      });

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      final result = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);

      expect(result.isUnauthorized, isTrue);
      expect(result.status, equals(WeatherStatus.unauthorized));
      expect(result.message, equals(WeatherMessages.unauthorized));
    });

    test('6. HTTP 429 mengembalikan status rateLimited', () async {
      fakeHttpClient.statusCode = 429;
      fakeHttpClient.responseBody = jsonEncode({
        'cod': 429,
        'message': 'Your account is temporary blocked due to exceeding of requests limitation of your subscription type.',
      });

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      final result = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);

      expect(result.isRateLimited, isTrue);
      expect(result.status, equals(WeatherStatus.rateLimited));
      expect(result.message, equals(WeatherMessages.rateLimited));
    });

    test('7. HTTP 404 mengembalikan status notFound', () async {
      fakeHttpClient.statusCode = 404;
      fakeHttpClient.responseBody = jsonEncode({
        'cod': '404',
        'message': 'city not found',
      });

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      final result = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);

      expect(result.isNotFound, isTrue);
      expect(result.status, equals(WeatherStatus.notFound));
      expect(result.message, equals(WeatherMessages.notFound));
    });

    test('8. Batas waktu (timeout) mengembalikan status timeout', () async {
      fakeHttpClient.throwOnGetUrl = true;
      fakeHttpClient.getUrlException = TimeoutException('Connection timed out');

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      final result = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);

      expect(result.isTimeout, isTrue);
      expect(result.status, equals(WeatherStatus.timeout));
      expect(result.message, equals(WeatherMessages.timeout));
    });

    test('9. Kegagalan koneksi jaringan (network error) mengembalikan status networkError', () async {
      fakeHttpClient.throwOnGetUrl = true;
      fakeHttpClient.getUrlException = const SocketException('No Internet Connection');

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      final result = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);

      expect(result.isNetworkError, isTrue);
      expect(result.status, equals(WeatherStatus.networkError));
      expect(result.message, equals(WeatherMessages.networkError));
    });

    test('10. HTTP error lainnya (misal: 500) mengembalikan status apiError', () async {
      fakeHttpClient.statusCode = 500;
      fakeHttpClient.responseBody = 'Internal Server Error';

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      final result = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);

      expect(result.isApiError, isTrue);
      expect(result.status, equals(WeatherStatus.apiError));
      expect(result.message, contains('HTTP 500'));
    });

    test('11. JSON tidak valid mengembalikan status failure', () async {
      fakeHttpClient.statusCode = 200;
      fakeHttpClient.responseBody = '<html>Bukan format JSON</html>';

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      final result = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);

      expect(result.isFailure, isTrue);
      expect(result.message, equals(WeatherMessages.invalidFormat));
    });

    test('12. Field JSON penting tidak tersedia mengembalikan status failure', () async {
      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      // Kasus A: Map JSON bukan objek yang diharapkan (misal List)
      fakeHttpClient.responseBody = jsonEncode([1, 2, 3]);
      final resList = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);
      expect(resList.isFailure, isTrue);

      // Kasus B: Field 'main' hilang
      fakeHttpClient.responseBody = jsonEncode({
        'weather': [{'description': 'berawan'}],
        'cod': 200,
      });
      final resNoMain = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);
      expect(resNoMain.isFailure, isTrue);

      // Kasus C: Field 'temp' hilang dari 'main'
      fakeHttpClient.responseBody = jsonEncode({
        'main': {'humidity': 70},
        'weather': [{'description': 'berawan'}],
        'cod': 200,
      });
      final resNoTemp = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);
      expect(resNoTemp.isFailure, isTrue);

      // Kasus D: Field 'temp' bukan angka
      fakeHttpClient.responseBody = jsonEncode({
        'main': {'temp': 'tiga puluh derajat'},
        'weather': [{'description': 'berawan'}],
        'cod': 200,
      });
      final resInvalidTemp = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);
      expect(resInvalidTemp.isFailure, isTrue);

      // Kasus E: Field 'weather' kosong
      fakeHttpClient.responseBody = jsonEncode({
        'main': {'temp': 30.0},
        'weather': [],
        'cod': 200,
      });
      final resEmptyWeather = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);
      expect(resEmptyWeather.isFailure, isTrue);

      // Kasus F: Field 'description' kosong dan tidak ada 'main' pada weather
      fakeHttpClient.responseBody = jsonEncode({
        'main': {'temp': 30.0},
        'weather': [{'id': 800}],
        'cod': 200,
      });
      final resNoDesc = await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);
      expect(resNoDesc.isFailure, isTrue);
    });

    test('13. Koordinat latitude dan longitude diteruskan dengan benar ke URI request', () async {
      fakeHttpClient.responseBody = jsonEncode(createValidWeatherJson());

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      const lat = 1.1301;
      const lon = 104.0529;

      await client.getCurrentWeather(latitude: lat, longitude: lon);

      expect(fakeHttpClient.lastUri, isNotNull);
      final uri = fakeHttpClient.lastUri!;
      expect(uri.queryParameters['lat'], equals('1.1301'));
      expect(uri.queryParameters['lon'], equals('104.0529'));
      expect(uri.queryParameters['appid'], equals('dummy_api_key_123'));
    });

    test('14. Parameter units=metric disertakan pada URI request', () async {
      fakeHttpClient.responseBody = jsonEncode(createValidWeatherJson());

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);

      expect(fakeHttpClient.lastUri, isNotNull);
      expect(fakeHttpClient.lastUri!.queryParameters['units'], equals('metric'));
    });

    test('15. Parameter lang=id disertakan pada URI request', () async {
      fakeHttpClient.responseBody = jsonEncode(createValidWeatherJson());

      final client = OpenWeatherMapClient(
        config: testConfig,
        httpClientFactory: () => fakeHttpClient,
      );

      await client.getCurrentWeather(latitude: 1.0, longitude: 104.0);

      expect(fakeHttpClient.lastUri, isNotNull);
      expect(fakeHttpClient.lastUri!.queryParameters['lang'], equals('id'));
    });

    test('16. Fallback ke field weather.main jika description kosong', () {
      final jsonWithMainOnly = {
        'main': {'temp': 28.0},
        'weather': [
          {'main': 'Rain'}
        ],
        'cod': 200,
      };

      final result = OpenWeatherMapClient.parseOpenWeatherResponse(jsonWithMainOnly);
      expect(result.isSuccess, isTrue);
      expect(result.data!.description, equals('Rain'));
    });

    test('17. Cod status selain 200 pada payload JSON dipetakan ke apiError', () {
      final jsonError = {
        'cod': 400,
        'message': 'Nothing to geocode',
      };

      final result = OpenWeatherMapClient.parseOpenWeatherResponse(jsonError);
      expect(result.isApiError, isTrue);
      expect(result.message, contains('Nothing to geocode'));
    });
  });

  group('WeatherData Model Tests', () {
    test('equality, hashCode, dan toString mencocokkan data yang identik', () {
      const dataA = WeatherData(
        description: 'berawan',
        temperature: 30.0,
        cityName: 'Batam',
        latitude: 1.1301,
        longitude: 104.0529,
      );
      const dataB = WeatherData(
        description: 'berawan',
        temperature: 30.0,
        cityName: 'Batam',
        latitude: 1.1301,
        longitude: 104.0529,
      );
      const dataC = WeatherData(
        description: 'hujan',
        temperature: 25.0,
        cityName: 'Jakarta',
      );

      expect(dataA, equals(dataB));
      expect(dataA.hashCode, equals(dataB.hashCode));
      expect(dataA, isNot(equals(dataC)));
      expect(dataA.toString(), contains('WeatherData'));
      expect(dataA.toString(), contains('30.0°C'));
    });
  });

  group('WeatherResult Model Tests', () {
    test('factory constructors dan status flags bekerja sesuai enum status', () {
      const weatherData = WeatherData(description: 'cerah', temperature: 32.0);

      final success = WeatherResult.success(weatherData);
      final unconfigured = WeatherResult.unconfigured();
      final unauthorized = WeatherResult.unauthorized();
      final rateLimited = WeatherResult.rateLimited();
      final notFound = WeatherResult.notFound();
      final timeout = WeatherResult.timeout();
      final network = WeatherResult.networkError();
      final api = WeatherResult.apiError();
      final failure = WeatherResult.failure('Gagal');

      expect(success.isSuccess, isTrue);
      expect(success.data, equals(weatherData));
      expect(unconfigured.isUnconfigured, isTrue);
      expect(unauthorized.isUnauthorized, isTrue);
      expect(rateLimited.isRateLimited, isTrue);
      expect(notFound.isNotFound, isTrue);
      expect(timeout.isTimeout, isTrue);
      expect(network.isNetworkError, isTrue);
      expect(api.isApiError, isTrue);
      expect(failure.isFailure, isTrue);

      expect(success.toString(), contains('WeatherResult'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/core/config/weather_api_config.dart';

void main() {
  group('WeatherApiConfig (TASK-51)', () {
    test('1. Nilai default sesuai spesifikasi OpenWeatherMap', () {
      const config = WeatherApiConfig(apiKey: null);

      expect(
        config.endpoint,
        equals('https://api.openweathermap.org/data/2.5/weather'),
      );
      expect(config.units, equals('metric'));
      expect(config.lang, equals('id'));
      expect(config.timeout, equals(const Duration(seconds: 10)));
    });

    test('2. Kondisi unconfigured terdeteksi aman saat apiKey null', () {
      const config = WeatherApiConfig(apiKey: null);

      expect(config.isConfigured, isFalse);
      expect(config.isUnconfigured, isTrue);
      expect(config.apiKey, isNull);
      expect(
        config.unconfiguredMessage,
        equals('Layanan cuaca belum dikonfigurasi dengan API key.'),
      );
    });

    test('3. Kondisi unconfigured terdeteksi aman saat apiKey string kosong atau spasi', () {
      const emptyConfig = WeatherApiConfig(apiKey: '');
      expect(emptyConfig.isConfigured, isFalse);
      expect(emptyConfig.isUnconfigured, isTrue);

      const blankConfig = WeatherApiConfig(apiKey: '   ');
      expect(blankConfig.isConfigured, isFalse);
      expect(blankConfig.isUnconfigured, isTrue);

      final factoryUnconfigured = WeatherApiConfig.unconfigured();
      expect(factoryUnconfigured.isConfigured, isFalse);
      expect(factoryUnconfigured.isUnconfigured, isTrue);
    });

    test('4. buildQueryParams dan buildUri pada kondisi unconfigured tidak menyertakan appid', () {
      const config = WeatherApiConfig(apiKey: null);

      final params = config.buildQueryParams(
        latitude: 1.1301,
        longitude: 104.0529,
      );

      expect(params['lat'], equals('1.1301'));
      expect(params['lon'], equals('104.0529'));
      expect(params['units'], equals('metric'));
      expect(params['lang'], equals('id'));
      expect(params.containsKey('appid'), isFalse);

      final uri = config.buildUri(
        latitude: 1.1301,
        longitude: 104.0529,
      );

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('api.openweathermap.org'));
      expect(uri.path, equals('/data/2.5/weather'));
      expect(uri.queryParameters['lat'], equals('1.1301'));
      expect(uri.queryParameters['lon'], equals('104.0529'));
      expect(uri.queryParameters['units'], equals('metric'));
      expect(uri.queryParameters['lang'], equals('id'));
      expect(uri.queryParameters.containsKey('appid'), isFalse);
    });

    test('5. Kondisi terkonfigurasi dengan valid apiKey menyertakan appid dengan aman', () {
      const config = WeatherApiConfig(apiKey: 'sample_test_key_123');

      expect(config.isConfigured, isTrue);
      expect(config.isUnconfigured, isFalse);
      expect(config.apiKey, equals('sample_test_key_123'));

      final params = config.buildQueryParams(
        latitude: 1.1301,
        longitude: 104.0529,
      );

      expect(params['lat'], equals('1.1301'));
      expect(params['lon'], equals('104.0529'));
      expect(params['units'], equals('metric'));
      expect(params['lang'], equals('id'));
      expect(params['appid'], equals('sample_test_key_123'));

      final uri = config.buildUri(
        latitude: 1.1301,
        longitude: 104.0529,
      );

      expect(uri.queryParameters['appid'], equals('sample_test_key_123'));
    });

    test('6. Whitespace pada apiKey dibersihkan (trimmed) saat buildQueryParams', () {
      const config = WeatherApiConfig(apiKey: '  sample_key_with_padding  ');

      expect(config.isConfigured, isTrue);
      final params = config.buildQueryParams(
        latitude: -6.2088,
        longitude: 106.8456,
      );

      expect(params['appid'], equals('sample_key_with_padding'));
    });

    test('7. copyWith menghasilkan konfigurasi baru tanpa mengubah objek asli', () {
      const original = WeatherApiConfig(apiKey: 'key_1');
      final updated = original.copyWith(
        apiKey: 'key_2',
        units: 'imperial',
        lang: 'en',
      );

      expect(original.apiKey, equals('key_1'));
      expect(original.units, equals('metric'));
      expect(original.lang, equals('id'));

      expect(updated.apiKey, equals('key_2'));
      expect(updated.units, equals('imperial'));
      expect(updated.lang, equals('en'));
      expect(updated.endpoint, equals(original.endpoint));
    });

    test('8. toString tidak membocorkan apiKey rahasia ke log (keamanan NFR-05)', () {
      const secretKey = 'my_super_secret_openweathermap_key';
      const config = WeatherApiConfig(apiKey: secretKey);

      final str = config.toString();
      expect(str, isNot(contains(secretKey)));
      expect(str, contains('apiKey: ***'));

      const unconfigured = WeatherApiConfig(apiKey: null);
      expect(unconfigured.toString(), contains('apiKey: unconfigured'));
    });

    test('9. Equality dan hashCode bekerja dengan benar untuk perbandingan objek', () {
      const configA = WeatherApiConfig(
        endpoint: 'https://custom.endpoint.com',
        apiKey: 'key_a',
        units: 'metric',
        lang: 'id',
      );
      const configB = WeatherApiConfig(
        endpoint: 'https://custom.endpoint.com',
        apiKey: 'key_a',
        units: 'metric',
        lang: 'id',
      );
      const configC = WeatherApiConfig(
        endpoint: 'https://custom.endpoint.com',
        apiKey: 'key_different',
        units: 'metric',
        lang: 'id',
      );

      expect(configA, equals(configB));
      expect(configA.hashCode, equals(configB.hashCode));
      expect(configA, isNot(equals(configC)));
    });
  });
}

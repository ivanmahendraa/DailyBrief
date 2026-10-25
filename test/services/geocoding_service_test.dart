import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:daily_brief/services/geocoding_service.dart';

class _FakeGeocodingClient implements GeocodingClient {
  double? lastLatitude;
  double? lastLongitude;
  int callCount = 0;

  GeocodingResult resultToReturn = GeocodingResult.success(
    const LocationAddress(
      city: 'Batam',
      province: 'Kepulauan Riau',
      country: 'Indonesia',
      formattedAddress: 'Batam, Kepulauan Riau, Indonesia',
    ),
  );

  bool throwException = false;
  Object? customException;

  @override
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    callCount++;
    lastLatitude = latitude;
    lastLongitude = longitude;

    if (throwException) {
      if (customException != null) {
        throw customException!;
      }
      throw StateError('Client reverse geocoding failed');
    }

    return resultToReturn;
  }
}

void main() {
  group('GeocodingService Unit Tests (TASK-47)', () {
    late _FakeGeocodingClient fakeClient;
    late GeocodingService geocodingService;

    setUp(() {
      fakeClient = _FakeGeocodingClient();
      geocodingService = GeocodingService(fakeClient);
    });

    test('1. Reverse geocoding berhasil dan meneruskan latitude/longitude dengan benar', () async {
      const lat = 1.1301;
      const lon = 104.0529;

      final result = await geocodingService.reverseGeocode(
        latitude: lat,
        longitude: lon,
      );

      expect(fakeClient.callCount, 1);
      expect(fakeClient.lastLatitude, lat);
      expect(fakeClient.lastLongitude, lon);
      expect(result.isSuccess, isTrue);
      expect(result.status, GeocodingStatus.success);
      expect(result.address, isNotNull);
      expect(result.address!.city, 'Batam');
      expect(result.address!.province, 'Kepulauan Riau');
      expect(result.address!.country, 'Indonesia');
      expect(
        result.address!.formattedAddress,
        'Batam, Kepulauan Riau, Indonesia',
      );
      expect(result.message, GeocodingMessages.success);
    });

    test('2. Menangani kondisi lokasi tidak ditemukan (notFound)', () async {
      fakeClient.resultToReturn = GeocodingResult.notFound();

      final result = await geocodingService.reverseGeocode(
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isNotFound, isTrue);
      expect(result.status, GeocodingStatus.notFound);
      expect(result.message, GeocodingMessages.notFound);
      expect(result.address, isNull);
    });

    test('3. Menangani kondisi error jaringan (networkError)', () async {
      fakeClient.resultToReturn = GeocodingResult.networkError();

      final result = await geocodingService.reverseGeocode(
        latitude: -6.2088,
        longitude: 106.8456,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isNetworkError, isTrue);
      expect(result.status, GeocodingStatus.networkError);
      expect(result.message, GeocodingMessages.networkError);
      expect(result.address, isNull);
    });

    test('4. Menangani kondisi error API (apiError)', () async {
      fakeClient.resultToReturn = GeocodingResult.apiError(
        'Layanan geocoding ditolak: REQUEST_DENIED',
      );

      final result = await geocodingService.reverseGeocode(
        latitude: -6.2088,
        longitude: 106.8456,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isApiError, isTrue);
      expect(result.status, GeocodingStatus.apiError);
      expect(result.message, contains('REQUEST_DENIED'));
      expect(result.address, isNull);
    });

    test(
      '5. Menangani exception tak terduga dari client dengan aman tanpa crash',
      () async {
        fakeClient.throwException = true;
        fakeClient.customException = StateError('Koneksi terputus tiba-tiba');

        final result = await geocodingService.reverseGeocode(
          latitude: 1.0,
          longitude: 100.0,
        );

        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.status, GeocodingStatus.failure);
        expect(result.message, contains(GeocodingMessages.failure));
        expect(result.message, contains('Koneksi terputus tiba-tiba'));
      },
    );

    test(
      '6. Data lokasi yang sebagian kosong/null ditangani dengan aman',
      () async {
        fakeClient.resultToReturn = GeocodingResult.success(
          const LocationAddress(
            city: 'Batam',
            province: null,
            country: null,
            formattedAddress: null,
          ),
        );

        final result = await geocodingService.reverseGeocode(
          latitude: 1.13,
          longitude: 104.05,
        );

        expect(result.isSuccess, isTrue);
        expect(result.address!.city, 'Batam');
        expect(result.address!.province, isNull);
        expect(result.address!.country, isNull);
        expect(result.address!.displayName, 'Batam');
      },
    );
  });

  group('DeviceGeocodingClient Tests', () {
    test('maps native placemark fields to a speakable location', () async {
      double? receivedLatitude;
      double? receivedLongitude;
      final client = DeviceGeocodingClient(
        lookup: (latitude, longitude) async {
          receivedLatitude = latitude;
          receivedLongitude = longitude;
          return const [
            Placemark(
              locality: 'Batam',
              subLocality: 'Batam Kota',
              administrativeArea: 'Kepulauan Riau',
              country: 'Indonesia',
            ),
          ];
        },
      );

      final result = await client.reverseGeocode(
        latitude: 1.1301,
        longitude: 104.0529,
      );

      expect(receivedLatitude, 1.1301);
      expect(receivedLongitude, 104.0529);
      expect(result.isSuccess, isTrue);
      expect(result.address?.city, 'Batam');
      expect(result.address?.subLocality, 'Batam Kota');
      expect(result.address?.province, 'Kepulauan Riau');
      expect(result.address?.country, 'Indonesia');
      expect(result.address?.displayName, 'Batam, Kepulauan Riau');
    });

    test(
      'falls back to administrative area when locality is missing',
      () async {
        final client = DeviceGeocodingClient(
          lookup: (_, _) async => const [
            Placemark(
              subAdministrativeArea: 'Kabupaten Sleman',
              administrativeArea: 'Daerah Istimewa Yogyakarta',
            ),
          ],
        );

        final result = await client.reverseGeocode(
          latitude: -7.7,
          longitude: 110.3,
        );

        expect(result.isSuccess, isTrue);
        expect(result.address?.city, 'Kabupaten Sleman');
      },
    );

    test(
      'returns notFound when the native geocoder has no placemark',
      () async {
        final client = DeviceGeocodingClient(lookup: (_, _) async => const []);

        final result = await client.reverseGeocode(latitude: 0, longitude: 0);

        expect(result.isNotFound, isTrue);
      },
    );

    test('maps native geocoder IO errors to network errors', () async {
      final client = DeviceGeocodingClient(
        lookup: (_, _) =>
            Future<List<Placemark>>.error(PlatformException(code: 'IO_ERROR')),
      );

      final result = await client.reverseGeocode(
        latitude: -6.2,
        longitude: 106.8,
      );

      expect(result.isNetworkError, isTrue);
    });
  });

  group('GoogleGeocodingClient & Parsing Tests', () {
    test('mengembalikan unconfigured saat API key tidak disediakan', () async {
      final client = GoogleGeocodingClient(apiKey: null);
      final result = await client.reverseGeocode(
        latitude: 1.0,
        longitude: 104.0,
      );

      expect(result.isUnconfigured, isTrue);
      expect(result.status, GeocodingStatus.unconfigured);
      expect(result.message, GeocodingMessages.unconfigured);
    });

    test(
      'mengembalikan unconfigured saat API key berupa string kosong',
      () async {
        final client = GoogleGeocodingClient(apiKey: '   ');
        final result = await client.reverseGeocode(
          latitude: 1.0,
          longitude: 104.0,
        );

        expect(result.isUnconfigured, isTrue);
      },
    );

    test('parseGoogleGeocodingResponse memetakan respons sukses lengkap dengan benar', () {
      final jsonResponse = {
        'status': 'OK',
        'results': [
          {
            'formatted_address': 'Jl. Engku Putri, Batam Kota, Kota Batam, Kepulauan Riau 29432, Indonesia',
            'address_components': [
              {
                'long_name': 'Mega Mall Batam',
                'short_name': 'Mega Mall',
                'types': ['point_of_interest', 'establishment'],
              },
              {
                'long_name': 'Batam Kota',
                'short_name': 'Batam Kota',
                'types': ['sublocality', 'political'],
              },
              {
                'long_name': 'Kota Batam',
                'short_name': 'Kota Batam',
                'types': ['administrative_area_level_2', 'political'],
              },
              {
                'long_name': 'Kepulauan Riau',
                'short_name': 'Kepri',
                'types': ['administrative_area_level_1', 'political'],
              },
              {
                'long_name': 'Indonesia',
                'short_name': 'ID',
                'types': ['country', 'political'],
              },
            ],
          },
        ],
      };

      final result = GoogleGeocodingClient.parseGoogleGeocodingResponse(
        jsonResponse,
      );

      expect(result.isSuccess, isTrue);
      expect(result.address, isNotNull);
      expect(result.address!.placeName, 'Mega Mall Batam');
      expect(result.address!.city, 'Kota Batam');
      expect(result.address!.subLocality, 'Batam Kota');
      expect(result.address!.province, 'Kepulauan Riau');
      expect(result.address!.country, 'Indonesia');
      expect(result.address!.formattedAddress, contains('Jl. Engku Putri'));
      expect(result.address!.displayName, 'Mega Mall Batam, Kota Batam');
    });

    test('parseGoogleGeocodingResponse memprioritaskan locality dibanding adminAreaLevel2', () {
      final jsonResponse = {
        'status': 'OK',
        'results': [
          {
            'formatted_address': 'Batam',
            'address_components': [
              {
                'long_name': 'Batam',
                'short_name': 'Batam',
                'types': ['locality', 'political'],
              },
              {
                'long_name': 'Kota Batam',
                'short_name': 'Kota Batam',
                'types': ['administrative_area_level_2', 'political'],
              },
            ],
          },
        ],
      };

      final result = GoogleGeocodingClient.parseGoogleGeocodingResponse(
        jsonResponse,
      );

      expect(result.isSuccess, isTrue);
      expect(result.address!.city, 'Batam');
    });

    test(
      'parseGoogleGeocodingResponse menangani ZERO_RESULTS sebagai notFound',
      () {
        final jsonResponse = {'status': 'ZERO_RESULTS', 'results': <dynamic>[]};

        final result = GoogleGeocodingClient.parseGoogleGeocodingResponse(
          jsonResponse,
        );

        expect(result.isNotFound, isTrue);
        expect(result.status, GeocodingStatus.notFound);
      },
    );

    test(
      'parseGoogleGeocodingResponse menangani REQUEST_DENIED sebagai apiError',
      () {
        final jsonResponse = {
          'status': 'REQUEST_DENIED',
          'error_message': 'The provided API key is invalid.',
        };

        final result = GoogleGeocodingClient.parseGoogleGeocodingResponse(
          jsonResponse,
        );

        expect(result.isApiError, isTrue);
        expect(result.message, contains('The provided API key is invalid.'));
      },
    );

    test(
      'parseGoogleGeocodingResponse menangani hasil kosong atau format salah',
      () {
        final emptyResults = {'status': 'OK', 'results': <dynamic>[]};
        expect(
          GoogleGeocodingClient.parseGoogleGeocodingResponse(emptyResults)
              .isNotFound,
          isTrue,
        );

        final invalidElements = {
          'status': 'OK',
          'results': ['string-bukan-map'],
        };
        expect(
          GoogleGeocodingClient.parseGoogleGeocodingResponse(invalidElements)
              .isNotFound,
          isTrue,
        );
      },
    );
  });

  group('LocationAddress Model Tests', () {
    test(
      'displayName mengembalikan kombinasi yang tepat sesuai ketersediaan data',
      () {
        const full = LocationAddress(
          placeName: 'Kantor Walikota',
          city: 'Batam',
          province: 'Kepulauan Riau',
        );
        expect(full.displayName, 'Kantor Walikota, Batam');

        const cityAndProvince = LocationAddress(
          city: 'Batam',
          province: 'Kepulauan Riau',
        );
        expect(cityAndProvince.displayName, 'Batam, Kepulauan Riau');

        const cityOnly = LocationAddress(city: 'Batam');
        expect(cityOnly.displayName, 'Batam');

        const subLocalityOnly = LocationAddress(subLocality: 'Sekupang');
        expect(subLocalityOnly.displayName, 'Sekupang');

        const provinceOnly = LocationAddress(province: 'Kepulauan Riau');
        expect(provinceOnly.displayName, 'Kepulauan Riau');

        const formattedOnly = LocationAddress(
          formattedAddress: 'Jalan Sudirman No. 1',
        );
        expect(formattedOnly.displayName, 'Jalan Sudirman No. 1');

        const countryOnly = LocationAddress(country: 'Indonesia');
        expect(countryOnly.displayName, 'Indonesia');

        const empty = LocationAddress();
        expect(empty.displayName, '');
      },
    );

    test('equality dan hashCode mencocokkan objek yang identik nilainya', () {
      const a = LocationAddress(city: 'Batam', province: 'Kepri');
      const b = LocationAddress(city: 'Batam', province: 'Kepri');
      const c = LocationAddress(city: 'Medan', province: 'Sumut');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a == c, isFalse);
      expect(a.toString(), contains('LocationAddress'));
    });
  });

  group('GeocodingResult Model Tests', () {
    test('factory constructors and status flags', () {
      final success = GeocodingResult.success(
        const LocationAddress(city: 'Batam'),
      );
      final notFound = GeocodingResult.notFound();
      final network = GeocodingResult.networkError();
      final api = GeocodingResult.apiError();
      final failure = GeocodingResult.failure('Gagal');

      expect(success.isSuccess, isTrue);
      expect(notFound.isNotFound, isTrue);
      expect(network.isNetworkError, isTrue);
      expect(api.isApiError, isTrue);
      expect(failure.isFailure, isTrue);
      expect(success.toString(), contains('GeocodingResult'));
    });
  });
}

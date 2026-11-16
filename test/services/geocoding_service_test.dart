import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

class _FakePlaceSearchClient implements PlaceSearchClient {
  _FakePlaceSearchClient(this.resultToReturn);

  final PlaceSearchResult resultToReturn;

  @override
  Future<PlaceSearchResult> searchPlace(String query) async => resultToReturn;
}

class _FakeNominatimHttpClient extends Fake implements HttpClient {
  final requestedUris = <Uri>[];
  @override
  String? userAgent;
  int statusCode = 200;
  String responseBody = '{}';
  Object? requestError;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestedUris.add(url);
    if (requestError case final error?) throw error;
    return _FakeNominatimHttpClientRequest(statusCode, responseBody);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeNominatimHttpClientRequest extends Fake
    implements HttpClientRequest {
  final int statusCode;
  final String responseBody;

  _FakeNominatimHttpClientRequest(this.statusCode, this.responseBody);

  @override
  Future<HttpClientResponse> close() async =>
      _FakeNominatimHttpClientResponse(statusCode, responseBody);
}

class _FakeNominatimHttpClientResponse extends Stream<List<int>>
    with Fake
    implements HttpClientResponse {
  @override
  final int statusCode;
  final String body;

  _FakeNominatimHttpClientResponse(this.statusCode, this.body);

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

  group('NominatimGeocodingClient', () {
    late _FakeNominatimHttpClient httpClient;
    late NominatimGeocodingClient client;

    setUp(() {
      httpClient = _FakeNominatimHttpClient();
      client = NominatimGeocodingClient(
        httpClientFactory: () => httpClient,
        requestGate: NominatimRequestGate(minimumInterval: Duration.zero),
      );
    });

    test(
      'requests an Indonesian reverse lookup and maps OSM address fields',
      () async {
        httpClient.responseBody = jsonEncode({
          'name': 'Mega Mall Batam',
          'display_name':
              'Mega Mall Batam, Teluk Tering, Batam, Kepulauan Riau, Indonesia',
          'address': {
            'house_number': '12',
            'road': 'Jalan Engku Putri',
            'suburb': 'Teluk Tering',
            'city': 'Batam',
            'state': 'Kepulauan Riau',
            'country': 'Indonesia',
          },
        });

        final result = await client.reverseGeocode(
          latitude: 1.1301,
          longitude: 104.0529,
        );

        expect(result.isSuccess, isTrue);
        expect(result.address?.street, 'Jalan Engku Putri');
        expect(result.address?.streetNumber, '12');
        expect(result.address?.subLocality, 'Teluk Tering');
        expect(result.address?.city, 'Batam');
        expect(result.address?.province, 'Kepulauan Riau');
        expect(result.address?.country, 'Indonesia');
        expect(result.address?.placeName, 'Mega Mall Batam');
        expect(
          result.address?.speechAddress,
          'Teluk Tering, Batam, Kepulauan Riau, Indonesia',
        );

        final uri = httpClient.requestedUris.single;
        expect(uri.host, 'nominatim.openstreetmap.org');
        expect(uri.path, '/reverse');
        expect(uri.queryParameters['format'], 'jsonv2');
        expect(uri.queryParameters['lat'], '1.1301');
        expect(uri.queryParameters['lon'], '104.0529');
        expect(uri.queryParameters['addressdetails'], '1');
        expect(uri.queryParameters['accept-language'], 'id');
        expect(httpClient.userAgent, NominatimGeocodingClient.defaultUserAgent);
      },
    );

    test(
      'caches repeated reverse lookups for the same nearby coordinates',
      () async {
        httpClient.responseBody = jsonEncode({
          'display_name': 'Batam, Indonesia',
          'address': {'city': 'Batam', 'country': 'Indonesia'},
        });

        final first = await client.reverseGeocode(
          latitude: 1.13011,
          longitude: 104.05291,
        );
        final second = await client.reverseGeocode(
          latitude: 1.13012,
          longitude: 104.05292,
        );

        expect(first, second);
        expect(httpClient.requestedUris, hasLength(1));
      },
    );

    test('maps empty, rate-limited, and server-error responses', () async {
      httpClient.responseBody = '{}';
      expect(
        (await client.reverseGeocode(latitude: 1, longitude: 104)).isNotFound,
        isTrue,
      );

      httpClient
        ..statusCode = 429
        ..responseBody = '{"error":"Too Many Requests"}';
      expect(
        (await client.reverseGeocode(
          latitude: 2,
          longitude: 104,
        )).isRateLimited,
        isTrue,
      );

      httpClient.statusCode = 500;
      expect(
        (await client.reverseGeocode(latitude: 3, longitude: 104)).isApiError,
        isTrue,
      );
    });

    test('maps network, timeout, and invalid JSON responses', () async {
      httpClient.requestError = const SocketException('offline');
      expect(
        (await client.reverseGeocode(
          latitude: 1,
          longitude: 104,
        )).isNetworkError,
        isTrue,
      );

      httpClient.requestError = TimeoutException('request timed out');
      expect(
        (await client.reverseGeocode(
          latitude: 2,
          longitude: 104,
        )).isNetworkError,
        isTrue,
      );

      httpClient
        ..requestError = null
        ..responseBody = '<html>invalid</html>';
      expect(
        (await client.reverseGeocode(latitude: 3, longitude: 104)).isFailure,
        isTrue,
      );
    });
  });

  group('NominatimPlaceSearchClient', () {
    late _FakeNominatimHttpClient httpClient;
    late NominatimPlaceSearchClient client;

    setUp(() {
      httpClient = _FakeNominatimHttpClient();
      client = NominatimPlaceSearchClient(
        httpClientFactory: () => httpClient,
        requestGate: NominatimRequestGate(minimumInterval: Duration.zero),
      );
    });

    test(
      'searches a user-requested place and returns its coordinates',
      () async {
        httpClient.responseBody = jsonEncode([
          {
            'lat': '3.5952',
            'lon': '98.6722',
            'name': 'Politeknik Negeri Medan',
            'display_name':
                'Politeknik Negeri Medan, Medan, Sumatera Utara, Indonesia',
            'address': {
              'city': 'Medan',
              'state': 'Sumatera Utara',
              'country': 'Indonesia',
            },
          },
        ]);

        final result = await client.searchPlace('Politeknik Negeri Medan');

        expect(result.isSuccess, isTrue);
        expect(result.latitude, 3.5952);
        expect(result.longitude, 98.6722);
        expect(result.address?.city, 'Medan');
        expect(
          httpClient.requestedUris.single.queryParameters['q'],
          'Politeknik Negeri Medan',
        );
        expect(httpClient.requestedUris.single.path, '/search');
        expect(
          httpClient.requestedUris.single.queryParameters['format'],
          'jsonv2',
        );
        expect(httpClient.requestedUris.single.queryParameters['limit'], '5');
        expect(
          httpClient.requestedUris.single.queryParameters['countrycodes'],
          isNull,
        );
        expect(httpClient.userAgent, NominatimGeocodingClient.defaultUserAgent);
      },
    );

    test('bounds Batam searches and selects a result in Batam, Indonesia', () async {
      httpClient.responseBody = jsonEncode([
        {
          'lat': '37.7749',
          'lon': '-122.4194',
          'name': 'Politeknik Negeri Batam',
          'display_name': 'Politeknik Negeri Batam, California, United States',
          'address': {'city': 'San Francisco', 'country': 'United States'},
        },
        {
          'lat': '1.1031',
          'lon': '104.0384',
          'name': 'Politeknik Negeri Batam',
          'display_name':
              'Politeknik Negeri Batam, Batam, Kepulauan Riau, Indonesia',
          'address': {
            'city': 'Batam',
            'state': 'Kepulauan Riau',
            'country': 'Indonesia',
          },
        },
      ]);

      final result = await client.searchPlace('Politeknik Negeri Batam');
      final parameters = httpClient.requestedUris.single.queryParameters;

      expect(result.isSuccess, isTrue);
      expect(result.latitude, 1.1031);
      expect(result.longitude, 104.0384);
      expect(result.address?.city, 'Batam');
      expect(parameters['countrycodes'], 'id');
      expect(parameters['viewbox'], NominatimPlaceSearchClient.batamViewbox);
      expect(parameters['bounded'], '1');
    });

    test('requests clarification when no Batam result matches the region', () async {
      httpClient.responseBody = jsonEncode([
        {
          'lat': '37.7749',
          'lon': '-122.4194',
          'name': 'Politeknik Negeri Batam',
          'display_name': 'Politeknik Negeri Batam, California, United States',
          'address': {'city': 'San Francisco', 'country': 'United States'},
        },
      ]);

      final result = await client.searchPlace('Politeknik Negeri Batam');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Batam'));
      expect(result.message, contains('?'));
    });

    test('requests clarification when an exact name has multiple Batam matches', () async {
      httpClient.responseBody = jsonEncode([
        {
          'lat': '1.1000',
          'lon': '104.0000',
          'name': 'Taman Sari Batam',
          'display_name': 'Taman Sari Batam, Batu Ampar, Batam, Indonesia',
          'address': {
            'city': 'Batam',
            'suburb': 'Batu Ampar',
            'country': 'Indonesia',
          },
        },
        {
          'lat': '1.1700',
          'lon': '104.1000',
          'name': 'Taman Sari Batam',
          'display_name': 'Taman Sari Batam, Nongsa, Batam, Indonesia',
          'address': {
            'city': 'Batam',
            'suburb': 'Nongsa',
            'country': 'Indonesia',
          },
        },
      ]);

      final result = await client.searchPlace('Taman Sari Batam');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('beberapa tempat'));
      expect(result.message, contains('?'));
    });

    test(
      'returns not found or an explicit failure for invalid results',
      () async {
        httpClient.responseBody = '[]';
        expect(
          (await client.searchPlace('Tempat yang tidak ada')).isSuccess,
          isFalse,
        );

        httpClient.responseBody = '[{"lat":"invalid","lon":"98.6"}]';
        final result = await client.searchPlace('Tempat invalid');
        expect(result.isSuccess, isFalse);
        expect(result.message, contains('Koordinat'));
      },
    );
  });

  group('PlaceSearchService', () {
    test('rejects a Batam query when the result city does not match', () async {
      final service = PlaceSearchService(
        _FakePlaceSearchClient(
          PlaceSearchResult.success(
            address: const LocationAddress(
              city: 'Medan',
              province: 'Sumatera Utara',
              country: 'Indonesia',
            ),
            latitude: 3.5952,
            longitude: 98.6722,
          ),
        ),
      );

      final result = await service.searchPlace('Politeknik Negeri Batam');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Batam'));
      expect(result.message, contains('?'));
    });
  });

  group('LocationAddress Model Tests', () {
    test(
      'speechAddress hanya menggabungkan komponen administratif sesuai urutan',
      () {
        const address = LocationAddress(
          street: 'Jalan Engku Putri',
          streetNumber: '12',
          subLocality: 'Teluk Tering',
          district: 'Batam Kota',
          city: 'Kota Batam',
          province: 'Kepulauan Riau',
          country: 'Indonesia',
        );

        expect(
          address.speechAddress,
          'Teluk Tering, Kecamatan Batam Kota, Kota Batam, Kepulauan Riau, Indonesia',
        );
      },
    );

    test(
      'speechAddress mengabaikan formattedAddress dan field alamat terperinci',
      () {
        const address = LocationAddress(
          street: '22C4+R39',
          streetNumber: '22C4+R39',
          subLocality: 'Tembesi',
          district: 'Sagulung',
          city: 'Kota Batam',
          province: 'Kepulauan Riau',
          country: 'Indonesia',
          formattedAddress: '22C4+R39, Tembesi, Kec. Sagulung, Kota Batam, Kepulauan Riau 29472, Indonesia',
        );

        expect(
          address.speechAddress,
          'Tembesi, Kecamatan Sagulung, Kota Batam, Kepulauan Riau, Indonesia',
        );
      },
    );

    test(
      'speechAddress melewati komponen kosong dan menghapus nilai duplikat',
      () {
        const address = LocationAddress(
          street: 'Jalan Engku Putri',
          streetNumber: '  ',
          subLocality: '',
          district: 'Batam Kota',
          city: 'Kota Batam',
          province: 'Kota Batam',
          country: null,
        );

        expect(address.speechAddress, 'Kecamatan Batam Kota, Kota Batam');
        expect(address.speechAddress, isNot(contains(',, ')));
      },
    );

    test(
      'speechAddress menyertakan kota, provinsi, dan negara yang tersedia',
      () {
        const address = LocationAddress(
          city: 'Kota Batam',
          province: 'Kepulauan Riau',
          country: 'Indonesia',
        );

        expect(address.speechAddress, 'Kota Batam, Kepulauan Riau, Indonesia');
      },
    );

    test('speechAddress mengabaikan jalan dan nomor rumah', () {
      const address = LocationAddress(
        street: 'Jalan Engku Putri No. 12',
        streetNumber: '12',
        city: 'Batam',
      );

      expect(address.speechAddress, 'Batam');
    });

    test('speechAddress kosong tanpa komponen administratif yang tersedia', () {
      expect(const LocationAddress().speechAddress, isEmpty);
      expect(
        const LocationAddress(formattedAddress: 'Jalan Sudirman No. 1, Batam')
            .speechAddress,
        isEmpty,
      );
      expect(
        const LocationAddress(placeName: 'Mega Mall Batam').speechAddress,
        isEmpty,
      );
    });

    test(
      'speechAddress does not repeat district if it already has its label',
      () {
        const address = LocationAddress(
          subLocality: 'Tembesi',
          district: 'Kecamatan Sagulung',
          city: 'Kota Batam',
          province: 'Kepulauan Riau',
          country: 'Indonesia',
        );

        expect(
          address.speechAddress,
          'Tembesi, Kecamatan Sagulung, Kota Batam, Kepulauan Riau, Indonesia',
        );
      },
    );

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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
import 'package:daily_brief/models/location_address.dart';

export 'package:daily_brief/models/location_address.dart';

/// Menyediakan pesan standar untuk pencarian dan geocoding lokasi.
class GeocodingMessages {
  const GeocodingMessages._();

  static const String success = 'Informasi lokasi berhasil ditemukan.';
  static const String notFound =
      'Nama lokasi tidak ditemukan untuk koordinat ini.';
  static const String networkError =
      'Gagal terhubung ke layanan lokasi. Periksa koneksi internet Anda.';
  static const String rateLimited =
      'Batas permintaan layanan lokasi tercapai. Silakan coba lagi nanti.';
  static const String apiError = 'Terjadi kesalahan pada layanan geocoding.';
  static const String placeClarification =
      'Saya belum dapat memastikan lokasi tersebut di Batam. Bisa sebutkan nama tempat beserta kecamatan atau patokan terdekat?';
  static const String ambiguousPlaceClarification =
      'Saya menemukan beberapa tempat dengan nama serupa. Kota atau kecamatan mana yang Anda maksud?';
  static const String unconfigured =
      'Layanan geocoding belum dikonfigurasi dengan API key.';
  static const String failure =
      'Terjadi kesalahan saat menerjemahkan koordinat lokasi.';
}

/// Menentukan status hasil geocoding.
enum GeocodingStatus {
  success,
  notFound,
  networkError,
  rateLimited,
  apiError,
  unconfigured,
  failure,
}

/// Menyimpan status, alamat, dan pesan hasil geocoding.
@immutable
class GeocodingResult {
  final GeocodingStatus status;
  final LocationAddress? address;
  final String message;

  const GeocodingResult({
    required this.status,
    this.address,
    required this.message,
  });

  factory GeocodingResult.success(LocationAddress address) => GeocodingResult(
    status: GeocodingStatus.success,
    address: address,
    message: GeocodingMessages.success,
  );

  factory GeocodingResult.notFound([String? message]) => GeocodingResult(
    status: GeocodingStatus.notFound,
    message: message ?? GeocodingMessages.notFound,
  );

  factory GeocodingResult.networkError([String? message]) => GeocodingResult(
    status: GeocodingStatus.networkError,
    message: message ?? GeocodingMessages.networkError,
  );

  factory GeocodingResult.rateLimited([String? message]) => GeocodingResult(
    status: GeocodingStatus.rateLimited,
    message: message ?? GeocodingMessages.rateLimited,
  );

  factory GeocodingResult.apiError([String? message]) => GeocodingResult(
    status: GeocodingStatus.apiError,
    message: message ?? GeocodingMessages.apiError,
  );

  factory GeocodingResult.unconfigured([String? message]) => GeocodingResult(
    status: GeocodingStatus.unconfigured,
    message: message ?? GeocodingMessages.unconfigured,
  );

  factory GeocodingResult.failure(String message) =>
      GeocodingResult(status: GeocodingStatus.failure, message: message);

  bool get isSuccess => status == GeocodingStatus.success;
  bool get isNotFound => status == GeocodingStatus.notFound;
  bool get isNetworkError => status == GeocodingStatus.networkError;
  bool get isRateLimited => status == GeocodingStatus.rateLimited;
  bool get isApiError => status == GeocodingStatus.apiError;
  bool get isUnconfigured => status == GeocodingStatus.unconfigured;
  bool get isFailure => !isSuccess;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeocodingResult &&
        other.status == status &&
        other.address == address &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(status, address, message);

  @override
  String toString() =>
      'GeocodingResult(status: $status, address: $address, message: $message)';
}

/// Mendefinisikan kontrak client untuk menerjemahkan koordinat menjadi alamat.
abstract interface class GeocodingClient {
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}

class NominatimRequestGate {
  NominatimRequestGate({this.minimumInterval = const Duration(seconds: 1)});

  static final NominatimRequestGate shared = NominatimRequestGate();

  final Duration minimumInterval;
  Future<void> _queue = Future<void>.value();
  DateTime? _lastRequestAt;

  Future<void> acquire() {
    final previous = _queue;
    final completer = Completer<void>();
    _queue = completer.future;
    return previous
        .then((_) async {
          final lastRequestAt = _lastRequestAt;
          if (lastRequestAt != null) {
            final wait =
                minimumInterval - DateTime.now().difference(lastRequestAt);
            if (wait > Duration.zero) await Future<void>.delayed(wait);
          }
          _lastRequestAt = DateTime.now();
        })
        .whenComplete(() {
          if (!completer.isCompleted) completer.complete();
        });
  }
}

/// Menerjemahkan koordinat menjadi alamat melalui layanan OpenStreetMap Nominatim.
class NominatimGeocodingClient implements GeocodingClient {
  static const String defaultEndpoint =
      'https://nominatim.openstreetmap.org/reverse';
  static const String defaultUserAgent = 'DailyBrief/1.0.0';

  NominatimGeocodingClient({
    this.httpClientFactory,
    this.timeout = const Duration(seconds: 10),
    this.endpoint = defaultEndpoint,
    this.userAgent = defaultUserAgent,
    NominatimRequestGate? requestGate,
  }) : _requestGate = requestGate ?? NominatimRequestGate.shared;

  final HttpClient Function()? httpClientFactory;
  final Duration timeout;
  final String endpoint;
  final String userAgent;
  final NominatimRequestGate _requestGate;
  final Map<String, GeocodingResult> _cache = {};
  final Map<String, Future<GeocodingResult>> _inFlight = {};

  @override
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final cacheKey =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    final cachedResult = _cache[cacheKey];
    if (cachedResult != null) return cachedResult;

    final pendingResult = _inFlight[cacheKey];
    if (pendingResult != null) return pendingResult;

    final request = _fetchAddress(latitude, longitude);
    _inFlight[cacheKey] = request;
    final result = await request;
    _inFlight.remove(cacheKey);
    if (result.isSuccess || result.isNotFound) {
      _cache[cacheKey] = result;
    }
    return result;
  }

  Future<GeocodingResult> _fetchAddress(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'addressdetails': '1',
        'accept-language': 'id',
        'zoom': '18',
      },
    );

    final client = httpClientFactory != null
        ? httpClientFactory!()
        : HttpClient();

    try {
      await _requestGate.acquire();
      client.userAgent = userAgent;
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);

      if (response.statusCode == 429) return GeocodingResult.rateLimited();
      if (response.statusCode != 200) {
        return GeocodingResult.apiError(
          '${GeocodingMessages.apiError} (HTTP ${response.statusCode})',
        );
      }

      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        return GeocodingResult.failure('Format data geocoding tidak valid.');
      }
      return parseNominatimResponse(data);
    } on SocketException catch (error, stackTrace) {
      debugPrint('NominatimGeocodingClient socket error: $error\n$stackTrace');
      return GeocodingResult.networkError();
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('NominatimGeocodingClient timeout: $error\n$stackTrace');
      return GeocodingResult.networkError(
        'Batas waktu koneksi geocoding habis. Silakan coba kembali.',
      );
    } on FormatException catch (error, stackTrace) {
      debugPrint('NominatimGeocodingClient format error: $error\n$stackTrace');
      return GeocodingResult.failure('Format data geocoding tidak valid.');
    } catch (error, stackTrace) {
      debugPrint(
        'NominatimGeocodingClient unexpected error: $error\n$stackTrace',
      );
      return GeocodingResult.failure('${GeocodingMessages.failure}: $error');
    } finally {
      if (httpClientFactory == null) client.close();
    }
  }

  static GeocodingResult parseNominatimResponse(Map<String, dynamic> data) {
    final rawAddress = data['address'];
    if (rawAddress is! Map<String, dynamic>) {
      return GeocodingResult.notFound();
    }

    String? valueFor(List<String> keys) {
      for (final key in keys) {
        final value = rawAddress[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    final address = LocationAddress(
      street: valueFor(['road', 'pedestrian', 'footway', 'residential']),
      streetNumber: valueFor(['house_number']),
      subLocality: valueFor(['suburb', 'neighbourhood', 'quarter', 'hamlet']),
      district: valueFor(['city_district', 'district', 'county']),
      city: valueFor(['city', 'town', 'village', 'municipality']),
      province: valueFor(['state', 'province', 'region']),
      country: valueFor(['country']),
      formattedAddress: data['display_name'] is String
          ? (data['display_name'] as String).trim()
          : null,
      placeName: data['name'] is String
          ? (data['name'] as String).trim()
          : null,
    );

    if (address.displayName.isEmpty) return GeocodingResult.notFound();
    return GeocodingResult.success(address);
  }
}

@immutable
class PlaceSearchResult {
  const PlaceSearchResult({
    required this.status,
    required this.message,
    this.address,
    this.latitude,
    this.longitude,
  });

  final GeocodingStatus status;
  final String message;
  final LocationAddress? address;
  final double? latitude;
  final double? longitude;

  bool get isSuccess => status == GeocodingStatus.success;

  factory PlaceSearchResult.success({
    required LocationAddress address,
    required double latitude,
    required double longitude,
  }) => PlaceSearchResult(
    status: GeocodingStatus.success,
    message: GeocodingMessages.success,
    address: address,
    latitude: latitude,
    longitude: longitude,
  );

  factory PlaceSearchResult.notFound() => const PlaceSearchResult(
    status: GeocodingStatus.notFound,
    message: GeocodingMessages.notFound,
  );

  factory PlaceSearchResult.networkError() => const PlaceSearchResult(
    status: GeocodingStatus.networkError,
    message: GeocodingMessages.networkError,
  );

  factory PlaceSearchResult.rateLimited() => const PlaceSearchResult(
    status: GeocodingStatus.rateLimited,
    message: GeocodingMessages.rateLimited,
  );

  factory PlaceSearchResult.apiError(String message) =>
      PlaceSearchResult(status: GeocodingStatus.apiError, message: message);

  factory PlaceSearchResult.failure(String message) =>
      PlaceSearchResult(status: GeocodingStatus.failure, message: message);

  factory PlaceSearchResult.clarification([String? message]) =>
      PlaceSearchResult(
        status: GeocodingStatus.failure,
        message: message ?? GeocodingMessages.placeClarification,
      );
}

abstract interface class PlaceSearchClient {
  Future<PlaceSearchResult> searchPlace(String query);
}

/// Mencari tempat berdasarkan nama melalui layanan OpenStreetMap Nominatim.
class NominatimPlaceSearchClient implements PlaceSearchClient {
  static const String defaultEndpoint =
      'https://nominatim.openstreetmap.org/search';
  static const String batamViewbox = '103.6514,1.2048,104.3708,0.4624';

  NominatimPlaceSearchClient({
    this.endpoint = defaultEndpoint,
    this.userAgent = NominatimGeocodingClient.defaultUserAgent,
    this.timeout = const Duration(seconds: 10),
    this.httpClientFactory,
    NominatimRequestGate? requestGate,
  }) : _requestGate = requestGate ?? NominatimRequestGate.shared;

  final String endpoint;
  final String userAgent;
  final Duration timeout;
  final HttpClient Function()? httpClientFactory;
  final NominatimRequestGate _requestGate;
  final Map<String, PlaceSearchResult> _cache = {};

  @override
  Future<PlaceSearchResult> searchPlace(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return PlaceSearchResult.notFound();
    final cacheKey = normalizedQuery.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final batamContext = _hasBatamContext(normalizedQuery);
    final queryParameters = {
      'q': normalizedQuery,
      'format': 'jsonv2',
      'addressdetails': '1',
      'accept-language': 'id',
      'limit': '5',
    };
    if (batamContext) {
      queryParameters.addAll({
        'countrycodes': 'id',
        'viewbox': batamViewbox,
        'bounded': '1',
      });
    }
    final uri = Uri.parse(endpoint).replace(
      queryParameters: queryParameters,
    );
    final client = httpClientFactory != null
        ? httpClientFactory!()
        : HttpClient();

    try {
      await _requestGate.acquire();
      client.userAgent = userAgent;
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);

      if (response.statusCode == 429) return PlaceSearchResult.rateLimited();
      if (response.statusCode != 200) {
        return PlaceSearchResult.apiError(
          '${GeocodingMessages.apiError} (HTTP ${response.statusCode})',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! List) {
        return PlaceSearchResult.notFound();
      }
      if (decoded.isEmpty) {
        return batamContext
            ? PlaceSearchResult.clarification()
            : PlaceSearchResult.notFound();
      }

      final candidates = <PlaceSearchResult>[];
      var hasInvalidCoordinates = false;
      var hasInvalidFormat = false;
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          hasInvalidFormat = true;
          continue;
        }

        final latitude = double.tryParse('${item['lat']}');
        final longitude = double.tryParse('${item['lon']}');
        if (latitude == null || longitude == null) {
          hasInvalidCoordinates = true;
          continue;
        }

        final geocodingResult = NominatimGeocodingClient.parseNominatimResponse(
          item,
        );
        final displayName = item['display_name'];
        final placeName = item['name'];
        final address =
            geocodingResult.address ??
            LocationAddress(
              placeName: placeName is String ? placeName : null,
              formattedAddress: displayName is String ? displayName : null,
            );
        if (address.displayName.isEmpty) continue;
        if (batamContext && !_isBatamAddress(address)) continue;

        candidates.add(
          PlaceSearchResult.success(
            address: address,
            latitude: latitude,
            longitude: longitude,
          ),
        );
      }

      if (candidates.isEmpty) {
        if (batamContext) return PlaceSearchResult.clarification();
        if (hasInvalidCoordinates) {
          return PlaceSearchResult.failure(
            'Koordinat lokasi dari layanan pencarian tidak valid.',
          );
        }
        if (hasInvalidFormat) {
          return PlaceSearchResult.failure(
            'Format data pencarian lokasi tidak valid.',
          );
        }
        return PlaceSearchResult.notFound();
      }

      if (_hasAmbiguousExactMatches(normalizedQuery, candidates)) {
        return PlaceSearchResult.clarification(
          GeocodingMessages.ambiguousPlaceClarification,
        );
      }

      final result = candidates.first;
      _cache[cacheKey] = result;
      return result;
    } on SocketException catch (error, stackTrace) {
      debugPrint(
        'NominatimPlaceSearchClient socket error: $error\n$stackTrace',
      );
      return PlaceSearchResult.networkError();
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('NominatimPlaceSearchClient timeout: $error\n$stackTrace');
      return PlaceSearchResult.networkError();
    } on FormatException catch (error, stackTrace) {
      debugPrint(
        'NominatimPlaceSearchClient format error: $error\n$stackTrace',
      );
      return PlaceSearchResult.failure(
        'Format data pencarian lokasi tidak valid.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'NominatimPlaceSearchClient unexpected error: $error\n$stackTrace',
      );
      return PlaceSearchResult.failure('${GeocodingMessages.failure}: $error');
    } finally {
      if (httpClientFactory == null) client.close();
    }
  }
}

class PlaceSearchService {
  PlaceSearchService([PlaceSearchClient? client])
    : _client = client ?? NominatimPlaceSearchClient();

  final PlaceSearchClient _client;

  Future<PlaceSearchResult> searchPlace(String query) async {
    try {
      final result = await _client.searchPlace(query);
      if (result.isSuccess &&
          _hasBatamContext(query) &&
          !_isBatamAddress(result.address)) {
        return PlaceSearchResult.clarification();
      }
      return result;
    } catch (error, stackTrace) {
      debugPrint('PlaceSearchService.searchPlace error: $error\n$stackTrace');
      return PlaceSearchResult.failure('${GeocodingMessages.failure}: $error');
    }
  }
}

bool _hasBatamContext(String query) =>
    RegExp(r'\bbatam\b', caseSensitive: false).hasMatch(query);

bool _isBatamAddress(LocationAddress? address) {
  if (address == null ||
      address.country?.trim().toLowerCase() != 'indonesia') {
    return false;
  }

  return [address.city, address.district].any(
    (value) =>
        value != null &&
        RegExp(r'\bbatam\b', caseSensitive: false).hasMatch(value),
  );
}

bool _hasAmbiguousExactMatches(
  String query,
  List<PlaceSearchResult> candidates,
) {
  final queryName = _normalizePlaceName(query);
  if (queryName.isEmpty || queryName == 'batam') return false;

  final distinctLocations = <String>{};
  for (final candidate in candidates) {
    final address = candidate.address;
    final latitude = candidate.latitude;
    final longitude = candidate.longitude;
    if (address == null || latitude == null || longitude == null) continue;

    final isExactMatch = [address.placeName, address.city].any(
      (name) => name != null && _normalizePlaceName(name) == queryName,
    );
    if (isExactMatch) {
      distinctLocations.add(
        '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}',
      );
    }
  }
  return distinctLocations.length > 1;
}

String _normalizePlaceName(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

typedef DevicePlacemarkLookup = Future<List<Placemark>> Function(
  double latitude,
  double longitude,
);

/// Menerjemahkan koordinat menjadi alamat melalui geocoder bawaan Android atau iOS.
class DeviceGeocodingClient implements GeocodingClient {
  DeviceGeocodingClient({DevicePlacemarkLookup? lookup})
    : _lookup = lookup ?? _lookupDevicePlacemark;

  static final Geocoding _geocoding = Geocoding(
    locale: const Locale('id', 'ID'),
  );

  final DevicePlacemarkLookup _lookup;

  static Future<List<Placemark>> _lookupDevicePlacemark(
    double latitude,
    double longitude,
  ) => _geocoding.placemarkFromCoordinates(latitude, longitude);

  @override
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await _lookup(latitude, longitude);
      if (placemarks.isEmpty) return GeocodingResult.notFound();

      final placemark = placemarks.first;
      final city =
          _nonEmpty(placemark.locality) ??
          _nonEmpty(placemark.subAdministrativeArea);
      final street =
          _nonEmpty(placemark.thoroughfare) ?? _nonEmpty(placemark.street);
      final streetNumber = _nonEmpty(placemark.subThoroughfare);
      final subLocality = _nonEmpty(placemark.subLocality);
      final province = _nonEmpty(placemark.administrativeArea);
      final country = _nonEmpty(placemark.country);
      final formattedAddress = [
        street,
        streetNumber,
        subLocality,
        city,
        province,
        country,
      ].whereType<String>().toSet().join(', ');

      final address = LocationAddress(
        street: street,
        streetNumber: streetNumber,
        city: city,
        subLocality: subLocality,
        province: province,
        country: country,
        formattedAddress: formattedAddress.isEmpty ? null : formattedAddress,
      );
      if (address.displayName.isEmpty) return GeocodingResult.notFound();

      return GeocodingResult.success(address);
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'DeviceGeocodingClient platform error: ${error.code}\n$stackTrace',
      );
      if (error.code == 'IO_ERROR') return GeocodingResult.networkError();
      return GeocodingResult.failure(GeocodingMessages.failure);
    } catch (error, stackTrace) {
      debugPrint('DeviceGeocodingClient error: $error\n$stackTrace');
      return GeocodingResult.failure(GeocodingMessages.failure);
    }
  }

  String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

/// Menerjemahkan koordinat menjadi alamat melalui Google Geocoding API.
///
/// Mengembalikan [GeocodingStatus.unconfigured] jika [apiKey] tidak tersedia atau kosong.
class GoogleGeocodingClient implements GeocodingClient {
  final String? apiKey;
  final HttpClient Function()? httpClientFactory;
  final Duration timeout;
  final String baseUrl;

  GoogleGeocodingClient({
    this.apiKey,
    this.httpClientFactory,
    this.timeout = const Duration(seconds: 10),
    this.baseUrl = 'https://maps.googleapis.com/maps/api/geocode/json',
  });

  @override
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (apiKey == null || apiKey!.trim().isEmpty) {
      return GeocodingResult.unconfigured();
    }

    final queryParams = {
      'latlng': '$latitude,$longitude',
      'key': apiKey!,
      'language': 'id',
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
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

      if (response.statusCode != 200) {
        return GeocodingResult.apiError(
          '${GeocodingMessages.apiError} (HTTP ${response.statusCode})',
        );
      }

      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        return GeocodingResult.failure('Format data geocoding tidak valid.');
      }

      return parseGoogleGeocodingResponse(data);
    } on SocketException catch (e, stackTrace) {
      debugPrint('GoogleGeocodingClient socket error: $e\n$stackTrace');
      return GeocodingResult.networkError();
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('GoogleGeocodingClient timeout: $e\n$stackTrace');
      return GeocodingResult.networkError(
        'Batas waktu koneksi geocoding habis. Silakan coba kembali.',
      );
    } on FormatException catch (e, stackTrace) {
      debugPrint('GoogleGeocodingClient format error: $e\n$stackTrace');
      return GeocodingResult.failure('Format data geocoding tidak valid.');
    } catch (e, stackTrace) {
      debugPrint('GoogleGeocodingClient unexpected error: $e\n$stackTrace');
      return GeocodingResult.failure('${GeocodingMessages.failure}: $e');
    } finally {
      if (httpClientFactory == null) {
        client.close();
      }
    }
  }

  /// Memetakan respons JSON Google Geocoding API ke [GeocodingResult].
  static GeocodingResult parseGoogleGeocodingResponse(
    Map<String, dynamic> data,
  ) {
    final status = data['status'] as String?;

    if (status == 'ZERO_RESULTS') {
      return GeocodingResult.notFound();
    }

    if (status != 'OK') {
      final errorMessage = data['error_message'] as String?;
      return GeocodingResult.apiError(
        errorMessage != null && errorMessage.isNotEmpty
            ? '${GeocodingMessages.apiError}: $errorMessage'
            : '${GeocodingMessages.apiError} (status: $status)',
      );
    }

    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return GeocodingResult.notFound();
    }

    final firstResult = results.first;
    if (firstResult is! Map<String, dynamic>) {
      return GeocodingResult.notFound();
    }

    final formattedAddress = firstResult['formatted_address'] as String?;
    final addressComponents =
        firstResult['address_components'] as List<dynamic>? ?? [];

    String? locality;
    String? adminAreaLevel2;
    String? street;
    String? streetNumber;
    String? subLocality;
    String? province;
    String? country;
    String? placeName;

    for (final component in addressComponents) {
      if (component is! Map<String, dynamic>) continue;

      final types =
          (component['types'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toSet() ??
          <String>{};
      final longName = component['long_name'] as String?;

      if (types.contains('route')) {
        street = longName;
      } else if (types.contains('street_number')) {
        streetNumber = longName;
      } else if (types.contains('locality')) {
        locality = longName;
      } else if (types.contains('administrative_area_level_2')) {
        adminAreaLevel2 = longName;
      } else if (types.contains('sublocality') ||
          types.contains('sublocality_level_1')) {
        subLocality = longName;
      } else if (types.contains('administrative_area_level_1')) {
        province = longName;
      } else if (types.contains('country')) {
        country = longName;
      } else if (types.contains('point_of_interest') ||
          types.contains('establishment')) {
        placeName = longName;
      }
    }

    final city = locality ?? adminAreaLevel2;

    final locationAddress = LocationAddress(
      street: street,
      streetNumber: streetNumber,
      city: city,
      subLocality: subLocality,
      province: province,
      country: country,
      formattedAddress: formattedAddress,
      placeName: placeName,
    );

    return GeocodingResult.success(locationAddress);
  }
}

/// Mengubah koordinat geografis menjadi informasi alamat melalui client geocoding.
class GeocodingService {
  final GeocodingClient _client;

  GeocodingService([GeocodingClient? client])
    : _client = client ?? NominatimGeocodingClient();

  /// Menerjemahkan koordinat [latitude] dan [longitude] menjadi [GeocodingResult].
  ///
  /// Mengembalikan hasil kegagalan jika client melempar pengecualian.
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      return await _client.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e, stackTrace) {
      debugPrint('GeocodingService.reverseGeocode error: $e\n$stackTrace');
      return GeocodingResult.failure('${GeocodingMessages.failure}: $e');
    }
  }
}

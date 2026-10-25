import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
import 'package:daily_brief/models/location_address.dart';

export 'package:daily_brief/models/location_address.dart';

/// Pesan standar yang digunakan terkait proses reverse geocoding.
class GeocodingMessages {
  const GeocodingMessages._();

  static const String success = 'Informasi lokasi berhasil ditemukan.';
  static const String notFound =
      'Nama lokasi tidak ditemukan untuk koordinat ini.';
  static const String networkError =
      'Gagal terhubung ke layanan lokasi. Periksa koneksi internet Anda.';
  static const String apiError = 'Terjadi kesalahan pada layanan geocoding.';
  static const String unconfigured =
      'Layanan geocoding belum dikonfigurasi dengan API key.';
  static const String failure =
      'Terjadi kesalahan saat menerjemahkan koordinat lokasi.';
}

/// Status hasil dari proses reverse geocoding.
enum GeocodingStatus {
  success,
  notFound,
  networkError,
  apiError,
  unconfigured,
  failure,
}

/// Representasi hasil dari pemanggilan reverse geocoding.
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

/// Kontrak abstraksi untuk client reverse geocoding,
/// memungkinkan dependency injection dan pengujian modular tanpa koneksi API nyata.
abstract interface class GeocodingClient {
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}

typedef DevicePlacemarkLookup = Future<List<Placemark>> Function(
  double latitude,
  double longitude,
);

/// Reverse geocoding backed by the native Android/iOS geocoder.
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
      final subLocality = _nonEmpty(placemark.subLocality);
      final province = _nonEmpty(placemark.administrativeArea);
      final country = _nonEmpty(placemark.country);
      final formattedAddress = [
        city,
        province,
        country,
      ].whereType<String>().toSet().join(', ');

      final address = LocationAddress(
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

/// Implementasi client reverse geocoding menggunakan Google Geocoding API (sesuai PRD.md).
///
/// Jika [apiKey] tidak tersedia atau kosong, client mengembalikan status [GeocodingStatus.unconfigured]
/// secara aman tanpa crash dan tanpa hard-coding secret key.
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

  /// Memetakan respons JSON dari Google Geocoding API ke [GeocodingResult].
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
    String? subLocality;
    String? adminAreaLevel3;
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

      if (types.contains('locality')) {
        locality = longName;
      } else if (types.contains('administrative_area_level_2')) {
        adminAreaLevel2 = longName;
      } else if (types.contains('sublocality') ||
          types.contains('sublocality_level_1')) {
        subLocality = longName;
      } else if (types.contains('administrative_area_level_3')) {
        adminAreaLevel3 = longName;
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
    final effectiveSubLocality = subLocality ?? adminAreaLevel3;

    final locationAddress = LocationAddress(
      city: city,
      subLocality: effectiveSubLocality,
      province: province,
      country: country,
      formattedAddress: formattedAddress,
      placeName: placeName,
    );

    return GeocodingResult.success(locationAddress);
  }
}

/// Service untuk menangani penerjemahan koordinat latitude dan longitude
/// menjadi informasi lokasi dan wilayah yang dapat dipahami.
///
/// Memenuhi kebutuhan TASK-47 dan FR-09 pada PRD.md.
class GeocodingService {
  final GeocodingClient _client;

  GeocodingService([GeocodingClient? client])
    : _client = client ?? DeviceGeocodingClient();

  /// Menerjemahkan koordinat [latitude] dan [longitude] menjadi [GeocodingResult].
  ///
  /// Menjamin bahwa proses tidak melempar exception yang menyebabkan aplikasi crash.
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

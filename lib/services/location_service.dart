import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Pesan standar yang digunakan terkait izin dan status layanan lokasi.
class LocationPermissionMessages {
  const LocationPermissionMessages._();

  static const String granted = 'Izin lokasi diberikan.';
  static const String denied =
      'Izin lokasi ditolak. Aplikasi membutuhkan izin lokasi untuk mengakses fitur ini.';
  static const String deniedForever =
      'Izin lokasi ditolak permanen. Silakan aktifkan izin lokasi di pengaturan aplikasi.';
  static const String serviceDisabled =
      'Layanan lokasi tidak aktif. Silakan aktifkan layanan lokasi pada perangkat.';
  static const String unableToDetermine =
      'Status izin lokasi tidak dapat ditentukan.';
  static const String error = 'Terjadi kesalahan saat memeriksa izin lokasi.';
}

/// Status izin lokasi aplikasi DailyBrief.
enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unableToDetermine,
  error,
}

/// Representasi hasil pemeriksaan atau permintaan izin lokasi.
@immutable
class LocationPermissionResult {
  final LocationPermissionStatus status;
  final String message;
  final LocationPermission? rawPermission;

  const LocationPermissionResult({
    required this.status,
    required this.message,
    this.rawPermission,
  });

  bool get isGranted => status == LocationPermissionStatus.granted;
  bool get isDenied => status == LocationPermissionStatus.denied;
  bool get isDeniedForever => status == LocationPermissionStatus.deniedForever;
  bool get isServiceDisabled =>
      status == LocationPermissionStatus.serviceDisabled;
  bool get isError => status == LocationPermissionStatus.error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationPermissionResult &&
        other.status == status &&
        other.message == message &&
        other.rawPermission == rawPermission;
  }

  @override
  int get hashCode => Object.hash(status, message, rawPermission);

  @override
  String toString() =>
      'LocationPermissionResult(status: $status, message: $message, rawPermission: $rawPermission)';
}

/// Kontrak abstraksi untuk wrapper platform geolocator,
/// memungkinkan pengujian modular tanpa memanggil native channel.
abstract interface class LocationClient {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

/// Implementasi default [LocationClient] yang menggunakan API statis dari `geolocator`.
class DefaultLocationClient implements LocationClient {
  const DefaultLocationClient();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Service untuk menangani pengecekan izin lokasi dan pengambilan koordinat posisi pengguna.
///
/// Memenuhi kebutuhan TASK-45 dan FR-09 pada PRD.md.
class LocationService {
  final LocationClient _client;

  LocationService([LocationClient? client])
    : _client = client ?? const DefaultLocationClient();

  /// Mengecek apakah permission termasuk kategori granted (`whileInUse` atau `always`).
  static bool isPermissionGranted(LocationPermission permission) {
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Mengecek apakah permission berstatus `denied`.
  static bool isPermissionDenied(LocationPermission permission) {
    return permission == LocationPermission.denied;
  }

  /// Mengecek apakah permission berstatus `deniedForever`.
  static bool isPermissionPermanentlyDenied(LocationPermission permission) {
    return permission == LocationPermission.deniedForever;
  }

  /// Memeriksa apakah layanan lokasi perangkat (GPS) sedang aktif.
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await _client.isLocationServiceEnabled();
    } catch (e, stackTrace) {
      debugPrint(
        'LocationService.isLocationServiceEnabled error: $e\n$stackTrace',
      );
      return false;
    }
  }

  /// Mengecek status izin lokasi saat ini dari platform geolocator.
  Future<LocationPermission> checkPermission() async {
    return await _client.checkPermission();
  }

  /// Meminta izin lokasi ke platform geolocator.
  Future<LocationPermission> requestPermission() async {
    return await _client.requestPermission();
  }

  /// Mengarahkan pengguna untuk membuka pengaturan aplikasi (berguna untuk `deniedForever`).
  Future<bool> openAppSettings() async {
    try {
      return await _client.openAppSettings();
    } catch (e, stackTrace) {
      debugPrint('LocationService.openAppSettings error: $e\n$stackTrace');
      return false;
    }
  }

  /// Mengarahkan pengguna untuk membuka pengaturan layanan lokasi perangkat.
  Future<bool> openLocationSettings() async {
    try {
      return await _client.openLocationSettings();
    } catch (e, stackTrace) {
      debugPrint('LocationService.openLocationSettings error: $e\n$stackTrace');
      return false;
    }
  }

  /// Mengecek status izin lokasi saat ini dan memetakannya ke [LocationPermissionResult].
  Future<LocationPermissionResult> checkPermissionStatus() async {
    try {
      final permission = await _client.checkPermission();
      return _mapPermissionToResult(permission);
    } catch (e, stackTrace) {
      debugPrint(
        'LocationService.checkPermissionStatus error: $e\n$stackTrace',
      );
      return const LocationPermissionResult(
        status: LocationPermissionStatus.error,
        message: LocationPermissionMessages.error,
      );
    }
  }

  /// Meminta izin lokasi secara terpadu dengan penanganan:
  /// 1. Pengecekan apakah layanan lokasi aktif (jika [checkServiceEnabled] bernilai `true`).
  /// 2. Pengecekan izin saat ini: jika sudah granted, langsung sukses.
  /// 3. Jika izin ditolak permanen (`deniedForever`), langsung kembalikan status `deniedForever`
  ///    tanpa memanggil `requestPermission()` yang sia-sia, disertai panduan ke pengaturan.
  /// 4. Jika izin `denied` atau `unableToDetermine`, lakukan permintaan izin `requestPermission()`.
  /// 5. Mengembalikan [LocationPermissionResult] sesuai respons pengguna.
  Future<LocationPermissionResult> requestLocationPermission({
    bool checkServiceEnabled = true,
  }) async {
    try {
      if (checkServiceEnabled) {
        final serviceEnabled = await isLocationServiceEnabled();
        if (!serviceEnabled) {
          return const LocationPermissionResult(
            status: LocationPermissionStatus.serviceDisabled,
            message: LocationPermissionMessages.serviceDisabled,
          );
        }
      }

      final currentPermission = await _client.checkPermission();

      if (isPermissionGranted(currentPermission)) {
        return LocationPermissionResult(
          status: LocationPermissionStatus.granted,
          message: LocationPermissionMessages.granted,
          rawPermission: currentPermission,
        );
      }

      if (isPermissionPermanentlyDenied(currentPermission)) {
        return const LocationPermissionResult(
          status: LocationPermissionStatus.deniedForever,
          message: LocationPermissionMessages.deniedForever,
          rawPermission: LocationPermission.deniedForever,
        );
      }

      final requestedPermission = await _client.requestPermission();
      return _mapPermissionToResult(requestedPermission);
    } catch (e, stackTrace) {
      debugPrint(
        'LocationService.requestLocationPermission error: $e\n$stackTrace',
      );
      return const LocationPermissionResult(
        status: LocationPermissionStatus.error,
        message: LocationPermissionMessages.error,
      );
    }
  }

  LocationPermissionResult _mapPermissionToResult(
    LocationPermission permission,
  ) {
    if (isPermissionGranted(permission)) {
      return LocationPermissionResult(
        status: LocationPermissionStatus.granted,
        message: LocationPermissionMessages.granted,
        rawPermission: permission,
      );
    }

    if (isPermissionPermanentlyDenied(permission)) {
      return const LocationPermissionResult(
        status: LocationPermissionStatus.deniedForever,
        message: LocationPermissionMessages.deniedForever,
        rawPermission: LocationPermission.deniedForever,
      );
    }

    if (isPermissionDenied(permission)) {
      return const LocationPermissionResult(
        status: LocationPermissionStatus.denied,
        message: LocationPermissionMessages.denied,
        rawPermission: LocationPermission.denied,
      );
    }

    return LocationPermissionResult(
      status: LocationPermissionStatus.unableToDetermine,
      message: LocationPermissionMessages.unableToDetermine,
      rawPermission: permission,
    );
  }
}

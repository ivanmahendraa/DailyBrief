import 'package:flutter/foundation.dart';

/// Model data yang merepresentasikan alamat dan informasi wilayah hasil reverse geocoding.
///
/// Memenuhi kebutuhan TASK-47 dan FR-09 pada PRD.md.
@immutable
class LocationAddress {
  /// Nama kota atau kabupaten (misal: "Kota Batam", "Batam", "Jakarta Pusat").
  final String? city;

  /// Nama kecamatan atau wilayah sub-lokal jika tersedia.
  final String? subLocality;

  /// Nama provinsi atau region (misal: "Kepulauan Riau", "DKI Jakarta").
  final String? province;

  /// Nama negara (misal: "Indonesia").
  final String? country;

  /// Alamat terformat lengkap dari penyedia geocoding jika tersedia.
  final String? formattedAddress;

  /// Nama tempat atau penanda lokasi spesifik jika tersedia.
  final String? placeName;

  const LocationAddress({
    this.city,
    this.subLocality,
    this.province,
    this.country,
    this.formattedAddress,
    this.placeName,
  });

  /// Mengembalikan nama lokasi yang representatif untuk dibacakan atau ditampilkan.
  ///
  /// Memprioritaskan:
  /// 1. Nama tempat spesifik jika tersedia.
  /// 2. Kota + Provinsi jika keduanya ada, atau Kota saja.
  /// 3. Sub-lokalitas / kecamatan.
  /// 4. Provinsi.
  /// 5. Negara.
  /// 6. Alamat terformat.
  String get displayName {
    if (placeName != null && placeName!.trim().isNotEmpty) {
      if (city != null && city!.trim().isNotEmpty) {
        return '$placeName, $city';
      }
      return placeName!;
    }

    if (city != null && city!.trim().isNotEmpty) {
      if (province != null && province!.trim().isNotEmpty) {
        return '$city, $province';
      }
      return city!;
    }

    if (subLocality != null && subLocality!.trim().isNotEmpty) {
      return subLocality!;
    }

    if (province != null && province!.trim().isNotEmpty) {
      return province!;
    }

    if (formattedAddress != null && formattedAddress!.trim().isNotEmpty) {
      return formattedAddress!;
    }

    return country ?? '';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationAddress &&
        other.city == city &&
        other.subLocality == subLocality &&
        other.province == province &&
        other.country == country &&
        other.formattedAddress == formattedAddress &&
        other.placeName == placeName;
  }

  @override
  int get hashCode => Object.hash(
    city,
    subLocality,
    province,
    country,
    formattedAddress,
    placeName,
  );

  @override
  String toString() =>
      'LocationAddress(city: $city, province: $province, country: $country, formattedAddress: $formattedAddress)';
}

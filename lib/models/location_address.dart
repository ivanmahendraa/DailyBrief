import 'package:flutter/foundation.dart';

/// Menyimpan komponen alamat dan wilayah dari hasil geocoding.
@immutable
class LocationAddress {
  /// Menyimpan nama jalan atau rute dari penyedia geocoding.
  final String? street;

  /// Menyimpan nomor alamat dari penyedia geocoding.
  final String? streetNumber;

  /// Menyimpan nama sublokalitas yang belum tentu setara dengan kelurahan atau desa.
  final String? subLocality;

  /// Menyimpan nama kecamatan jika penyedia mengidentifikasikannya secara eksplisit.
  final String? district;

  /// Menyimpan nama kota atau kabupaten, misalnya "Kota Batam" atau "Jakarta Pusat".
  final String? city;

  /// Menyimpan nama provinsi atau wilayah, misalnya "Kepulauan Riau" atau "DKI Jakarta".
  final String? province;

  /// Menyimpan nama negara, misalnya "Indonesia".
  final String? country;

  /// Menyimpan alamat lengkap terformat jika tersedia.
  final String? formattedAddress;

  /// Menyimpan nama tempat atau penanda lokasi spesifik jika tersedia.
  final String? placeName;

  const LocationAddress({
    this.street,
    this.streetNumber,
    this.subLocality,
    this.district,
    this.city,
    this.province,
    this.country,
    this.formattedAddress,
    this.placeName,
  });

  /// Menyusun nama lokasi yang representatif untuk dibacakan atau ditampilkan.
  ///
  /// Memilih komponen dengan urutan berikut:
  /// - Menggunakan nama tempat, disertai kota jika tersedia.
  /// - Menggunakan kota dan provinsi, atau kota saja.
  /// - Menggunakan sublokalitas.
  /// - Menggunakan provinsi.
  /// - Menggunakan alamat terformat.
  /// - Menggunakan negara sebagai pilihan terakhir.
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

  /// Merangkai komponen wilayah ringkas yang tersedia.
  String get speechAddress {
    final parts = <String>[];
    final seen = <String>{};

    void addPart(String? value, {bool districtName = false}) {
      final normalized = _nonEmpty(value);
      if (normalized == null) return;

      final key = normalized
          .toLowerCase()
          .replaceFirst(RegExp(r'^kecamatan\s+'), '')
          .replaceAll(RegExp(r'\s+'), ' ');
      if (!seen.add(key)) return;

      if (districtName && !normalized.toLowerCase().startsWith('kecamatan ')) {
        parts.add('Kecamatan $normalized');
      } else {
        parts.add(normalized);
      }
    }

    addPart(subLocality);
    addPart(district, districtName: true);
    addPart(city);
    addPart(province);
    addPart(country);

    return parts.join(', ');
  }

  /// Menandai nama tempat sebagai patokan perkiraan jika nama jalan tidak tersedia.
  bool get usesPlaceNameAsLandmark =>
      _nonEmpty(placeName) != null && _nonEmpty(street) == null;

  String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationAddress &&
        other.street == street &&
        other.streetNumber == streetNumber &&
        other.subLocality == subLocality &&
        other.district == district &&
        other.city == city &&
        other.province == province &&
        other.country == country &&
        other.formattedAddress == formattedAddress &&
        other.placeName == placeName;
  }

  @override
  int get hashCode => Object.hash(
    street,
    streetNumber,
    subLocality,
    district,
    city,
    province,
    country,
    formattedAddress,
    placeName,
  );

  @override
  String toString() =>
      'LocationAddress(city: $city, province: $province, country: $country, formattedAddress: $formattedAddress)';
}

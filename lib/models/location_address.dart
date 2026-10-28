import 'package:flutter/foundation.dart';

/// Model data yang merepresentasikan alamat dan informasi wilayah hasil reverse geocoding.
///
/// Memenuhi kebutuhan TASK-47 dan FR-09 pada PRD.md.
@immutable
class LocationAddress {
  /// Nama jalan atau rute sebagaimana diberikan provider.
  final String? street;

  /// Nomor alamat sebagaimana diberikan provider.
  final String? streetNumber;

  /// Nama sub-lokalitas; tidak selalu setara dengan kelurahan/desa.
  final String? subLocality;

  /// Nama kecamatan hanya jika provider mengidentifikasinya secara eksplisit.
  final String? district;

  /// Nama kota atau kabupaten (misal: "Kota Batam", "Batam", "Jakarta Pusat").
  final String? city;

  /// Nama provinsi atau region (misal: "Kepulauan Riau", "DKI Jakarta").
  final String? province;

  /// Nama negara (misal: "Indonesia").
  final String? country;

  /// Alamat terformat lengkap dari penyedia geocoding jika tersedia.
  final String? formattedAddress;

  /// Nama tempat atau penanda lokasi spesifik jika tersedia.
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

  /// Merangkai hanya komponen administratif ringkas yang tersedia.
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

  /// A place name is spoken as an approximate landmark when no street is known.
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

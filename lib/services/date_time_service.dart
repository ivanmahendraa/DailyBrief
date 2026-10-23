class DateTimeService {
  static const List<String> _weekdayNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  final DateTime Function() _now;

  DateTimeService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Returns the current local date and time from the device.
  DateTime get currentLocalDateTime => _now();

  /// Returns a spoken Indonesian response for the current local weekday.
  String get currentDayResponse {
    final weekday = _weekdayNames[currentLocalDateTime.weekday - 1];
    return 'Hari ini hari $weekday.';
  }

  /// Returns a spoken Indonesian response for the current local date.
  String get currentDateResponse {
    final date = currentLocalDateTime;
    final month = _monthNames[date.month - 1];
    return 'Hari ini tanggal ${date.day} $month ${date.year}.';
  }

  /// Returns a spoken Indonesian response for the current local time.
  String get currentTimeResponse {
    final time = currentLocalDateTime;
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = switch (time.hour) {
      >= 4 && <= 10 => 'pagi',
      >= 11 && <= 14 => 'siang',
      >= 15 && <= 18 => 'sore',
      _ => 'malam',
    };
    final timeDescription = time.minute == 0
        ? '$hour $period tepat'
        : '$hour $period lewat ${time.minute} menit';

    return 'Sekarang pukul $timeDescription.';
  }
}

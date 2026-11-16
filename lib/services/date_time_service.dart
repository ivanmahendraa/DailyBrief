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

  /// Mengembalikan tanggal dan waktu lokal saat ini.
  DateTime get currentLocalDateTime => _now();

  static String weekdayNameFor(DateTime date) =>
      _weekdayNames[date.weekday - 1];

  static String formatDate(DateTime date) =>
      '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

  String responseForDate(DateTime date, {bool includeWeekday = false}) {
    final dateText = formatDate(date);
    if (includeWeekday) {
      return 'Tanggal $dateText jatuh pada hari ${weekdayNameFor(date)}.';
    }

    return 'Tanggal $dateText.';
  }

  /// Menyusun respons lisan berbahasa Indonesia tentang hari ini.
  String get currentDayResponse {
    final weekday = weekdayNameFor(currentLocalDateTime);
    return 'Hari ini hari $weekday.';
  }

  /// Menyusun respons lisan berbahasa Indonesia tentang tanggal hari ini.
  String get currentDateResponse {
    return 'Hari ini tanggal ${formatDate(currentLocalDateTime)}.';
  }

  /// Menyusun respons lisan berbahasa Indonesia tentang waktu saat ini.
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

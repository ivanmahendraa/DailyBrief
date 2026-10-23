import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/services/date_time_service.dart';

void main() {
  group('DateTimeService', () {
    test('returns the injected local date and time', () {
      final expected = DateTime(2026, 10, 16, 1, 52, 51);
      final service = DateTimeService(now: () => expected);

      expect(service.currentLocalDateTime, expected);
      expect(service.currentLocalDateTime.isUtc, isFalse);
    });

    test('reads the current time each time it is requested', () {
      var current = DateTime(2026, 10, 16, 1);
      final service = DateTimeService(now: () => current);

      expect(service.currentLocalDateTime, current);

      current = DateTime(2026, 10, 16, 2);
      expect(service.currentLocalDateTime, current);
    });

    test('updates the spoken time when the local clock changes', () {
      var current = DateTime(2026, 10, 16, 13, 5);
      final service = DateTimeService(now: () => current);

      expect(
        service.currentTimeResponse,
        'Sekarang pukul 1 siang lewat 5 menit.',
      );

      current = DateTime(2026, 10, 16, 14);
      expect(service.currentTimeResponse, 'Sekarang pukul 2 siang tepat.');
    });

    test('formats each weekday as a spoken Indonesian response', () {
      const weekdayNames = [
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
        'Minggu',
      ];

      for (var index = 0; index < weekdayNames.length; index++) {
        final date = DateTime(2026, 10, 12 + index);
        final service = DateTimeService(now: () => date);

        expect(
          service.currentDayResponse,
          'Hari ini hari ${weekdayNames[index]}.',
        );
      }
    });

    test('formats each month as a spoken Indonesian date', () {
      const monthNames = [
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

      for (var month = 1; month <= monthNames.length; month++) {
        final service = DateTimeService(now: () => DateTime(2026, month, 16));

        expect(
          service.currentDateResponse,
          'Hari ini tanggal 16 ${monthNames[month - 1]} 2026.',
        );
      }
    });

    test('formats local time with Indonesian day periods', () {
      final cases = [
        (DateTime(2026, 10, 16, 0), 'Sekarang pukul 12 malam tepat.'),
        (DateTime(2026, 10, 16, 4), 'Sekarang pukul 4 pagi tepat.'),
        (DateTime(2026, 10, 16, 11), 'Sekarang pukul 11 siang tepat.'),
        (DateTime(2026, 10, 16, 12), 'Sekarang pukul 12 siang tepat.'),
        (DateTime(2026, 10, 16, 15), 'Sekarang pukul 3 sore tepat.'),
        (DateTime(2026, 10, 16, 19), 'Sekarang pukul 7 malam tepat.'),
        (
          DateTime(2026, 10, 16, 13, 5),
          'Sekarang pukul 1 siang lewat 5 menit.',
        ),
        (
          DateTime(2026, 10, 16, 23, 59),
          'Sekarang pukul 11 malam lewat 59 menit.',
        ),
      ];

      for (final (dateTime, expected) in cases) {
        final service = DateTimeService(now: () => dateTime);
        expect(service.currentTimeResponse, expected);
      }
    });

    test('uses the device local clock by default', () {
      final before = DateTime.now();
      final actual = DateTimeService().currentLocalDateTime;
      final after = DateTime.now();

      expect(actual.isUtc, isFalse);
      expect(actual.isBefore(before), isFalse);
      expect(actual.isAfter(after), isFalse);
    });
  });
}

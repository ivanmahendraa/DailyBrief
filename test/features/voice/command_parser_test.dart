import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/features/voice/command_parser.dart';

void main() {
  const parser = CommandParser();
  final now = DateTime(2026, 11, 16, 15, 30);

  ParsedCommand parse(String input, {bool previousWeatherContext = false}) =>
      parser.parse(
        input,
        now: now,
        previousWeatherContext: previousWeatherContext,
      );

  group('CommandParser', () {
    test('normalizes a bare weather request to today and device location', () {
      final parsed = parse('  CUACA!  ');

      expect(parsed.command, VoiceCommand.weather);
      expect(parsed.date, DateTime(2026, 11, 16));
      expect(parsed.locationName, isNull);
      expect(parsed.toJson(), {
        'intent': 'cuaca',
        'lokasi': 'saat_ini',
        'tanggal': '2026-11-16',
        'pertanyaan_khusus': null,
      });
    });

    test('extracts relative date and named city from a weather question', () {
      final parsed = parse('Apakah BESOK hujan di Batam?');

      expect(parsed.command, VoiceCommand.weather);
      expect(parsed.date, DateTime(2026, 11, 17));
      expect(parsed.locationName, 'batam');
      expect(parsed.specificQuestion, 'hujan');
    });

    test('resolves day counts and date words', () {
      final relative = parse('Tiga hari lagi');
      final absolute = parse('Sepuluh Desember di Medan');

      expect(relative.command, VoiceCommand.date);
      expect(relative.date, DateTime(2026, 11, 19));
      expect(absolute.command, VoiceCommand.weather);
      expect(absolute.date, DateTime(2026, 12, 10));
      expect(absolute.locationName, 'medan');
    });

    test('resolves yesterday for weather, weekday, and date questions', () {
      final weather = parse('Bagaimana cuaca kemarin?');
      final weekday = parse('Kemarin hari apa?');
      final date = parse('Kemarin tanggal berapa?');

      expect(weather.command, VoiceCommand.weather);
      expect(weather.date, DateTime(2026, 11, 15));
      expect(weekday.command, VoiceCommand.day);
      expect(weekday.date, DateTime(2026, 11, 15));
      expect(date.command, VoiceCommand.date);
      expect(date.date, DateTime(2026, 11, 15));
    });

    test('resolves numeric dates and weekdays', () {
      expect(parse('Cuaca tanggal 10/12').date, DateTime(2026, 12, 10));
      expect(parse('Hari Rabu').date, DateTime(2026, 11, 18));
    });

    test('uses the previous weather context for a date-only follow-up', () {
      final parsed = parser.parse(
        'Hari Rabu',
        now: now,
        previousWeatherContext: true,
        previousWeatherLocationName: 'Medan',
      );

      expect(parsed.command, VoiceCommand.weather);
      expect(parsed.date, DateTime(2026, 11, 18));
      expect(parsed.locationName, 'Medan');

      final localFollowUp = parser.parse(
        'Hari Rabu di sini',
        now: now,
        previousWeatherContext: true,
        previousWeatherLocationName: 'Medan',
      );
      expect(localFollowUp.command, VoiceCommand.weather);
      expect(localFollowUp.locationName, isNull);

      final yesterdayWeather = parser.parse(
        'Ya kemarin',
        now: now,
        previousWeatherContext: true,
        previousWeatherLocationName: 'Medan',
      );
      expect(yesterdayWeather.command, VoiceCommand.weather);
      expect(yesterdayWeather.date, DateTime(2026, 11, 15));
      expect(yesterdayWeather.locationName, 'Medan');

      final explicitWeather = parser.parse(
        'Ya cuaca kemarin',
        now: now,
        previousWeatherContext: true,
        previousWeatherLocationName: 'Medan',
      );
      expect(explicitWeather.command, VoiceCommand.weather);
      expect(explicitWeather.locationName, 'Medan');

      final weekdayQuestion = parser.parse(
        'Ya kemarin hari apa?',
        now: now,
        previousWeatherContext: true,
        previousWeatherLocationName: 'Medan',
      );
      expect(weekdayQuestion.command, VoiceCommand.day);
      expect(weekdayQuestion.date, DateTime(2026, 11, 15));

      final dateQuestion = parser.parse(
        'Ya kemarin tanggal berapa?',
        now: now,
        previousWeatherContext: true,
        previousWeatherLocationName: 'Medan',
      );
      expect(dateQuestion.command, VoiceCommand.date);
      expect(dateQuestion.date, DateTime(2026, 11, 15));
    });

    test('resolves location and date-information requests separately', () {
      final currentLocation = parse('Alamat saya');
      final namedLocation = parse('Lokasi Politeknik Negeri Batam');
      final weekday = parse('Tanggal 25 Desember hari apa?');

      expect(currentLocation.command, VoiceCommand.location);
      expect(currentLocation.toJson()['lokasi'], 'saat_ini');
      expect(namedLocation.command, VoiceCommand.location);
      expect(namedLocation.locationName, 'politeknik negeri batam');
      expect(weekday.command, VoiceCommand.day);
      expect(weekday.date, DateTime(2026, 12, 25));
      expect(weekday.specificQuestion, 'nama_hari');
      expect(weekday.toJson(), {
        'intent': 'tanggal',
        'lokasi': null,
        'tanggal': '2026-12-25',
        'pertanyaan_khusus': 'nama_hari',
      });
    });

    test('uses current location for deictic weather requests', () {
      final parsed = parse('Cuaca lusa di sini');

      expect(parsed.command, VoiceCommand.weather);
      expect(parsed.date, DateTime(2026, 11, 18));
      expect(parsed.locationName, isNull);
    });

    test('preserves day, date, and time commands', () {
      expect(parse('Hari ini hari apa').command, VoiceCommand.day);
      expect(parse('Tanggal berapa').command, VoiceCommand.date);
      expect(parse('Sekarang pukul berapa').command, VoiceCommand.time);
    });

    test('does not guess when a request is invalid or unrecognized', () {
      expect(parse('').command, VoiceCommand.unknown);
      expect(parse('tolong bantu saya').command, VoiceCommand.unknown);
      expect(parse('Tanggal 32 Desember').command, VoiceCommand.unknown);
      expect(parse('jangan cek cuaca').command, VoiceCommand.unknown);
    });
  });
}

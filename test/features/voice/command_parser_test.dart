import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/features/voice/command_parser.dart';

void main() {
  const parser = CommandParser();

  group('CommandParser', () {
    test('classifies each supported command type', () {
      expect(parser.parse('hari'), VoiceCommand.day);
      expect(parser.parse('tanggal'), VoiceCommand.date);
      expect(parser.parse('jam berapa'), VoiceCommand.time);
      expect(parser.parse('cuaca'), VoiceCommand.weather);
      expect(parser.parse('lokasi saya'), VoiceCommand.location);
    });

    test('matches commands regardless of capitalization', () {
      expect(parser.parse('HARI INI'), VoiceCommand.day);
      expect(parser.parse('TANGGAL BERAPA'), VoiceCommand.date);
      expect(parser.parse('JAM BERAPA'), VoiceCommand.time);
      expect(parser.parse('RAMALAN CUACA'), VoiceCommand.weather);
      expect(parser.parse('LOKASI SAYA'), VoiceCommand.location);
    });

    test('collapses excess whitespace and trims the input', () {
      expect(parser.parse('  hari   ini  '), VoiceCommand.day);
      expect(parser.parse('tanggal    berapa'), VoiceCommand.date);
      expect(parser.parse('jam\tberapa'), VoiceCommand.time);
      expect(parser.parse('prakiraan   cuaca'), VoiceCommand.weather);
      expect(parser.parse('saya   di mana'), VoiceCommand.location);
    });

    test('ignores common punctuation around command phrases', () {
      expect(parser.parse('Hari ini?'), VoiceCommand.day);
      expect(parser.parse('Tanggal, berapa!'), VoiceCommand.date);
      expect(parser.parse('Jam berapa.'), VoiceCommand.time);
      expect(parser.parse('Bagaimana cuaca hari ini?'), VoiceCommand.weather);
      expect(parser.parse('Di mana lokasi saya?'), VoiceCommand.location);
    });

    test('recognizes every supported Indonesian utterance variation', () {
      const utterancesByCommand = {
        VoiceCommand.day: [
          'hari',
          'hari ini',
          'hari apa',
          'hari ini hari apa',
          'sekarang hari apa',
        ],
        VoiceCommand.date: [
          'tanggal',
          'tanggal berapa',
          'tanggal hari ini',
          'tanggal hari ini berapa',
          'tanggal berapa hari ini',
          'tanggal berapa sekarang',
        ],
        VoiceCommand.time: [
          'jam',
          'jam berapa',
          'waktu',
          'waktu sekarang',
          'jam berapa sekarang',
          'sekarang jam berapa',
          'sekarang pukul berapa',
          'pukul',
          'pukul berapa',
          'tolong beri tahu waktu sekarang',
        ],
        VoiceCommand.weather: [
          'cuaca',
          'ramalan cuaca',
          'prakiraan cuaca',
          'bagaimana cuaca hari ini',
          'bagaimana cuaca',
          'cuaca hari ini',
          'bagaimana prakiraan cuaca hari ini',
          'tolong cek cuaca',
        ],
        VoiceCommand.location: [
          'lokasi',
          'lokasi saya',
          'posisi saya',
          'saya di mana',
          'saya dimana',
          'saya berada di mana',
          'saya berada dimana',
          'saya sedang berada di mana',
          'di mana saya',
          'dimana saya',
          'di mana lokasi saya',
          'saya di mana sekarang',
        ],
      };

      for (final entry in utterancesByCommand.entries) {
        for (final utterance in entry.value) {
          expect(
            parser.parse(utterance),
            entry.key,
            reason: 'Expected "$utterance" to map to ${entry.key}.',
          );
        }
      }
    });

    test('returns unknown for empty and unrecognized input', () {
      expect(parser.parse(''), VoiceCommand.unknown);
      expect(parser.parse(' \t\n '), VoiceCommand.unknown);
      expect(parser.parse('tolong bantu saya'), VoiceCommand.unknown);
      expect(parser.parse('sehari yang menyenangkan'), VoiceCommand.unknown);
    });

    test('rejects unsupported sentences containing command keywords', () {
      expect(parser.parse('jangan cek cuaca'), VoiceCommand.unknown);
      expect(parser.parse('saya tidak tahu hari ini'), VoiceCommand.unknown);
      expect(parser.parse('seharian'), VoiceCommand.unknown);
      expect(parser.parse('cuacanya'), VoiceCommand.unknown);
      expect(parser.parse('lokasinya'), VoiceCommand.unknown);
      expect(parser.parse('cuaca besok'), VoiceCommand.unknown);
      expect(parser.parse('bagaimana cuaca besok'), VoiceCommand.unknown);
      expect(parser.parse('apakah besok akan hujan'), VoiceCommand.unknown);
      expect(parser.parse('berapa suhu besok'), VoiceCommand.unknown);
    });

    test('returns unknown when multiple intents are spoken', () {
      expect(parser.parse('cuaca dan tanggal hari ini'), VoiceCommand.unknown);
      expect(parser.parse('jam dan cuaca'), VoiceCommand.unknown);
    });
  });
}

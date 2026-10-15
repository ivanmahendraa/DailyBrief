enum VoiceCommand { day, date, time, weather, location, unknown }

/// Classifies recognized Indonesian speech without invoking device services.
class CommandParser {
  const CommandParser();

  static const Set<String> _dayUtterances = {
    'hari',
    'hari ini',
    'hari apa',
    'sekarang hari apa',
  };

  static const Set<String> _dateUtterances = {
    'tanggal',
    'tanggal berapa',
    'tanggal hari ini',
    'tanggal hari ini berapa',
  };

  static const Set<String> _timeUtterances = {
    'jam',
    'jam berapa',
    'waktu',
    'waktu sekarang',
    'pukul',
    'pukul berapa',
    'tolong beri tahu waktu sekarang',
  };

  static const Set<String> _weatherUtterances = {
    'cuaca',
    'ramalan cuaca',
    'prakiraan cuaca',
    'bagaimana cuaca hari ini',
    'bagaimana prakiraan cuaca hari ini',
    'tolong cek cuaca',
  };

  static const Set<String> _locationUtterances = {
    'lokasi',
    'lokasi saya',
    'posisi saya',
    'saya di mana',
    'saya dimana',
    'saya berada di mana',
    'saya berada dimana',
    'di mana saya',
    'dimana saya',
    'di mana lokasi saya',
    'saya di mana sekarang',
  };

  VoiceCommand parse(String input) {
    final normalized = _normalize(input);
    if (normalized.isEmpty) return VoiceCommand.unknown;

    if (_dateUtterances.contains(normalized)) return VoiceCommand.date;
    if (_timeUtterances.contains(normalized)) return VoiceCommand.time;
    if (_weatherUtterances.contains(normalized)) return VoiceCommand.weather;
    if (_locationUtterances.contains(normalized)) return VoiceCommand.location;
    if (_dayUtterances.contains(normalized)) return VoiceCommand.day;
    return VoiceCommand.unknown;
  }

  String _normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[.,!?;:]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

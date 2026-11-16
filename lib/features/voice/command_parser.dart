import 'package:flutter/foundation.dart';

enum VoiceCommand { day, date, time, weather, location, unknown }

@immutable
class ParsedCommand {
  const ParsedCommand({
    required this.command,
    this.locationName,
    this.date,
    this.specificQuestion,
  });

  final VoiceCommand command;
  final String? locationName;
  final DateTime? date;
  final String? specificQuestion;

  Map<String, Object?> toJson() => {
    'intent': switch (command) {
      VoiceCommand.weather => 'cuaca',
      VoiceCommand.location => 'lokasi',
      VoiceCommand.day || VoiceCommand.date => 'tanggal',
      VoiceCommand.time => 'waktu',
      VoiceCommand.unknown => 'tidak_dikenali',
    },
    'lokasi': switch (command) {
      VoiceCommand.weather ||
      VoiceCommand.location => locationName ?? 'saat_ini',
      _ => null,
    },
    'tanggal': date == null
        ? null
        : '${date!.year.toString().padLeft(4, '0')}-'
              '${date!.month.toString().padLeft(2, '0')}-'
              '${date!.day.toString().padLeft(2, '0')}',
    'pertanyaan_khusus': specificQuestion,
  };
}

/// Mengurai teks perintah berbahasa Indonesia menjadi intent dan entitas terstandar.
class CommandParser {
  const CommandParser();

  static const Map<String, int> _months = {
    'januari': 1,
    'februari': 2,
    'maret': 3,
    'april': 4,
    'mei': 5,
    'juni': 6,
    'juli': 7,
    'agustus': 8,
    'september': 9,
    'oktober': 10,
    'november': 11,
    'desember': 12,
  };

  static const List<String> _weekdays = [
    'senin',
    'selasa',
    'rabu',
    'kamis',
    'jumat',
    'sabtu',
    'minggu',
  ];

  static const Map<String, int> _smallNumbers = {
    'nol': 0,
    'satu': 1,
    'se': 1,
    'dua': 2,
    'tiga': 3,
    'empat': 4,
    'lima': 5,
    'enam': 6,
    'tujuh': 7,
    'delapan': 8,
    'sembilan': 9,
    'sepuluh': 10,
    'sebelas': 11,
  };

  static const Set<String> _timeUtterances = {
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
  };

  static const Set<String> _currentLocationPhrases = {
    'lokasi',
    'lokasi saya',
    'posisi saya',
    'alamat saya',
    'jalan apa ini',
    'saya di mana',
    'saya dimana',
    'saya berada di mana',
    'saya berada dimana',
    'saya sedang berada di mana',
    'di mana saya',
    'dimana saya',
    'di mana lokasi saya',
    'dimana lokasi saya',
    'saya di mana sekarang',
    'di sini',
    'disini',
  };

  static const Set<String> _localLocationNames = {
    'saya',
    'sini',
    'di sini',
    'disini',
    'saat ini',
    'sekarang',
    'lokasi saya',
    'posisi saya',
  };

  ParsedCommand parse(
    String input, {
    DateTime? now,
    bool previousWeatherContext = false,
    String? previousWeatherLocationName,
  }) {
    final normalized = _normalize(input);
    if (normalized.isEmpty) {
      return const ParsedCommand(command: VoiceCommand.unknown);
    }

    final referenceDate = _dateOnly(now ?? DateTime.now());
    final extractedDate = _extractDate(normalized, referenceDate);
    final locationName = _extractLocation(normalized);
    final hasWeatherIntent = _hasWeatherIntent(normalized);
    final isLocationQuery = _isLocationQuery(normalized);
    final asksForWeekday = RegExp(r'\bhari\s+apa\b').hasMatch(normalized);
    final asksForDate = RegExp(r'\btanggal\s+berapa\b').hasMatch(normalized);

    if (_timeUtterances.contains(normalized)) {
      return const ParsedCommand(command: VoiceCommand.time);
    }

    if (isLocationQuery && !hasWeatherIntent) {
      return ParsedCommand(
        command: VoiceCommand.location,
        locationName: locationName,
      );
    }

    if (extractedDate == null && _hasInvalidExplicitDate(normalized)) {
      return const ParsedCommand(command: VoiceCommand.unknown);
    }

    if (asksForWeekday) {
      return ParsedCommand(
        command: VoiceCommand.day,
        date: extractedDate ?? referenceDate,
        specificQuestion: 'nama_hari',
      );
    }

    if (asksForDate) {
      return ParsedCommand(
        command: VoiceCommand.date,
        date: extractedDate ?? referenceDate,
      );
    }

    if (previousWeatherContext && extractedDate != null && !hasWeatherIntent) {
      return ParsedCommand(
        command: VoiceCommand.weather,
        locationName: _mentionsCurrentLocation(normalized)
            ? null
            : locationName ?? previousWeatherLocationName,
        date: extractedDate,
        specificQuestion: _specificWeatherQuestion(normalized),
      );
    }

    if (hasWeatherIntent || (extractedDate != null && locationName != null)) {
      return ParsedCommand(
        command: VoiceCommand.weather,
        locationName:
            locationName ??
            (previousWeatherContext &&
                    !_mentionsCurrentLocation(normalized)
                ? previousWeatherLocationName
                : null),
        date: extractedDate ?? referenceDate,
        specificQuestion: _specificWeatherQuestion(normalized),
      );
    }

    if (_hasDateQuestion(normalized) ||
        extractedDate != null ||
        _isDayPhrase(normalized)) {
      return ParsedCommand(
        command: _isDayPhrase(normalized)
            ? VoiceCommand.day
            : VoiceCommand.date,
        date: extractedDate ?? referenceDate,
        specificQuestion: _specificWeatherQuestion(normalized),
      );
    }

    if (_currentLocationPhrases.contains(normalized)) {
      return const ParsedCommand(command: VoiceCommand.location);
    }

    return const ParsedCommand(command: VoiceCommand.unknown);
  }

  String _normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[.,!?;:]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  DateTime? _extractDate(String input, DateTime today) {
    if (RegExp(r'\bhari ini\b').hasMatch(input) ||
        RegExp(r'\bsekarang\b').hasMatch(input)) {
      return today;
    }
    if (RegExp(r'\bkemarin\b').hasMatch(input)) {
      return today.subtract(const Duration(days: 1));
    }
    if (RegExp(r'\blusa\b').hasMatch(input)) {
      return today.add(const Duration(days: 2));
    }
    if (RegExp(r'\bbesok\b').hasMatch(input)) {
      return today.add(const Duration(days: 1));
    }

    final daysFromNow = RegExp(
      r'\b([a-z0-9]+(?:\s+(?:belas|puluh)\s+[a-z0-9]+)?)\s+hari\s+lagi\b',
    ).firstMatch(input);
    if (daysFromNow != null) {
      final amount = _parseNumber(daysFromNow.group(1)!);
      if (amount != null && amount >= 0 && amount <= 366) {
        return today.add(Duration(days: amount));
      }
    }

    final numericDate = RegExp(r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{4}))?\b')
        .firstMatch(input);
    if (numericDate != null) {
      return _validDate(
        int.parse(numericDate.group(3) ?? '${today.year}'),
        int.parse(numericDate.group(2)!),
        int.parse(numericDate.group(1)!),
      );
    }

    final namedDate = RegExp(
      r'\b(?:tanggal\s+)?([a-z0-9]+(?:\s+(?:belas|puluh)\s+[a-z0-9]+)?|\d{1,2})\s+([a-z]+)(?:\s+(\d{4}))?\b',
    ).firstMatch(input);
    if (namedDate != null) {
      final month = _months[namedDate.group(2)!];
      final day = _parseNumber(namedDate.group(1)!);
      if (month != null && day != null) {
        return _validDate(
          int.parse(namedDate.group(3) ?? '${today.year}'),
          month,
          day,
        );
      }
    }

    final weekdayMatch = RegExp(
      r"\bhari\s+(senin|selasa|rabu|kamis|jumat|jum['’]?at|sabtu|minggu)\b",
    ).firstMatch(input);
    if (weekdayMatch != null) {
      final weekday = weekdayMatch.group(1)!.replaceAll('’', '');
      final index = weekday == 'jumat' || weekday == "jum'at"
          ? 4
          : _weekdays.indexOf(weekday);
      if (index >= 0) {
        final difference = (index + 1 - today.weekday + 7) % 7;
        return today.add(Duration(days: difference));
      }
    }

    return null;
  }

  int? _parseNumber(String value) {
    final normalized = value.trim().toLowerCase();
    final numeric = int.tryParse(normalized);
    if (numeric != null) return numeric;

    final tokens = normalized.split(RegExp(r'\s+'));
    if (tokens.length == 1) return _smallNumbers[tokens.first];
    if (tokens.length == 2 && tokens[1] == 'belas') {
      final unit = _smallNumbers[tokens.first];
      return unit == null ? null : 10 + unit;
    }
    if (tokens.length == 2 && tokens[1] == 'puluh') {
      final tens = _smallNumbers[tokens.first];
      return tens == null ? null : tens * 10;
    }
    if (tokens.length == 3 && tokens[1] == 'puluh') {
      final tens = _smallNumbers[tokens.first];
      final ones = _smallNumbers[tokens[2]];
      return tens == null || ones == null ? null : tens * 10 + ones;
    }
    return null;
  }

  DateTime? _validDate(int year, int month, int day) {
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  String? _extractLocation(String input) {
    if (_currentLocationPhrases.contains(input)) return null;

    final explicitLocation = RegExp(r'\b(?:lokasi|alamat)\s+(?:di\s+)?(.+)$')
        .firstMatch(input);
    final locationAfterDi = RegExp(r'\bdi\s+(.+)$').firstMatch(input);
    final match = explicitLocation ?? locationAfterDi;
    if (match == null) return null;

    var candidate = match.group(1)!;
    for (final weekday in _weekdays) {
      candidate = candidate.replaceAll(RegExp('\\bhari\\s+$weekday\\b'), '');
    }
    candidate = candidate
        .replaceAll(
          RegExp(
            r'\b(?:hari ini|besok|lusa|sekarang|hari\s+\w+|\d+\s+hari\s+lagi)\b',
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\b(?:cuaca|ramalan|prakiraan|apakah|akan|hujan|suhu)\b'),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (candidate.isEmpty || _localLocationNames.contains(candidate)) {
      return null;
    }
    return candidate;
  }

  bool _hasWeatherIntent(String input) {
    if (RegExp(r'\b(?:jangan|tidak|bukan)\b').hasMatch(input) &&
        RegExp(r'\b(?:cuaca|hujan|suhu)\b').hasMatch(input)) {
      return false;
    }
    return RegExp(r'\b(?:cuaca|ramalan|prakiraan|hujan|suhu)\b')
        .hasMatch(input);
  }

  bool _isLocationQuery(String input) =>
      _currentLocationPhrases.contains(input) ||
      RegExp(r'^(?:lokasi|alamat)\b').hasMatch(input) ||
      RegExp(r'\b(?:jalan apa ini|alamat saya)\b').hasMatch(input);

  bool _mentionsCurrentLocation(String input) =>
      RegExp(r'\b(?:di sini|disini|lokasi saya|posisi saya|alamat saya)\b')
          .hasMatch(input) ||
      _currentLocationPhrases.contains(input);

  bool _hasDateQuestion(String input) => RegExp(
    r'\b(?:tanggal|hari ini|kemarin|besok|lusa|hari\s+(?:senin|selasa|rabu|kamis|jumat|sabtu|minggu)|\d{1,2}[/-]\d{1,2})\b',
  ).hasMatch(input);

  bool _isDayPhrase(String input) =>
      input == 'hari' ||
      input == 'hari ini' ||
      RegExp(r'\bhari\s+apa\b').hasMatch(input);

  bool _hasInvalidExplicitDate(String input) => RegExp(
    r'\b(?:\d{1,2}[/-]\d{1,2}(?:[/-]\d{4})?|(?:tanggal\s+)?(?:\d{1,2}|[a-z]+(?:\s+(?:belas|puluh)\s+[a-z]+)?)\s+(?:januari|februari|maret|april|mei|juni|juli|agustus|september|oktober|november|desember))\b',
  ).hasMatch(input);

  String? _specificWeatherQuestion(String input) {
    if (RegExp(r'\bhujan\b').hasMatch(input)) return 'hujan';
    if (RegExp(r'\bsuhu\b').hasMatch(input)) return 'suhu';
    return null;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

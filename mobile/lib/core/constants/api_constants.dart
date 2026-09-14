import 'dart:io';

class ApiConstants {
  /// Base API URL for DailyBrief backend.
  /// Android Emulator accesses host localhost via 10.0.2.2.
  /// Windows/Web accesses host localhost via 127.0.0.1.
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  static const String healthEndpoint = '/health';
}

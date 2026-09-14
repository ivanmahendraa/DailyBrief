import 'dart:convert';
import 'dart:io';
import '../../core/constants/api_constants.dart';

class HealthStatus {
  final bool isHealthy;
  final String message;
  final String appName;
  final String environment;
  final String databaseStatus;

  HealthStatus({
    required this.isHealthy,
    required this.message,
    required this.appName,
    required this.environment,
    required this.databaseStatus,
  });

  factory HealthStatus.fallback(String error) {
    return HealthStatus(
      isHealthy: false,
      message: error,
      appName: 'DailyBrief',
      environment: 'unknown',
      databaseStatus: 'unreachable',
    );
  }
}

class HealthService {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  Future<HealthStatus> checkHealth() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.healthEndpoint}');
      final request = await _client.getUrl(uri);
      final response = await request.close();

      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final innerData = data['data'] as Map<String, dynamic>? ?? {};
        return HealthStatus(
          isHealthy: data['success'] == true,
          message: data['message'] as String? ?? 'API is reachable',
          appName: innerData['app_name'] as String? ?? 'DailyBrief',
          environment: innerData['environment'] as String? ?? 'local',
          databaseStatus: innerData['database'] as String? ?? 'connected',
        );
      } else {
        return HealthStatus.fallback('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      return HealthStatus.fallback('Tidak dapat terhubung ke backend: ${e.toString()}');
    }
  }
}

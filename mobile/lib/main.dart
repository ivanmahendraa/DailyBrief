import 'package:flutter/material.dart';
import 'core/constants/api_constants.dart';
import 'core/theme/app_theme.dart';
import 'services/api/health_service.dart';

void main() {
  runApp(const DailyBriefApp());
}

class DailyBriefApp extends StatelessWidget {
  const DailyBriefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DailyBrief',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const StartScreen(),
    );
  }
}

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final HealthService _healthService = HealthService();
  bool _isLoading = false;
  HealthStatus? _status;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _healthService.checkHealth();

    if (!mounted) return;
    setState(() {
      _status = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.space24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon / Logo Indicator
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: const Icon(
                        Icons.newspaper_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space20),

                  // App Title
                  const Text(
                    'DailyBrief',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),

                  // Tagline
                  const Text(
                    'Temukan Informasi dalam Satu Sentuhan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space32),

                  // Connection Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.space20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isLoading
                                      ? AppTheme.warning
                                      : (_status?.isHealthy == true
                                          ? AppTheme.success
                                          : AppTheme.error),
                                ),
                              ),
                              const SizedBox(width: AppTheme.space8),
                              const Text(
                                'Status Koneksi Backend',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space16),

                          if (_isLoading) ...[
                            const Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                SizedBox(width: AppTheme.space12),
                                Text(
                                  'Memeriksa status server...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            _buildInfoRow(
                              'Server API',
                              _status?.isHealthy == true
                                  ? 'Terhubung (Online)'
                                  : 'Terputus (Offline)',
                              isHighlight: true,
                              isSuccess: _status?.isHealthy == true,
                            ),
                            const SizedBox(height: AppTheme.space8),
                            _buildInfoRow(
                              'Database',
                              _status?.databaseStatus ?? '-',
                            ),
                            const SizedBox(height: AppTheme.space8),
                            _buildInfoRow(
                              'Target URL',
                              ApiConstants.baseUrl,
                            ),
                            if (_status?.isHealthy != true && _status != null) ...[
                              const SizedBox(height: AppTheme.space12),
                              Container(
                                padding: const EdgeInsets.all(AppTheme.space12),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorLight,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                                child: Text(
                                  _status!.message,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),

                  // Retry Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _checkConnection,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Periksa Ulang'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isHighlight = false, bool isSuccess = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            color: isHighlight
                ? (isSuccess ? AppTheme.success : AppTheme.error)
                : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

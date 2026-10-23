import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/speech_to_text_service.dart';
import '../../../services/app_initializer.dart';
import '../../../services/tts_service.dart';
import '../../home/screens/home_screen.dart';

/// Halaman Splash Screen DailyBrief.
///
/// Menampilkan identitas aplikasi, logo/ikon, tagline, indikator pemuatan,
/// menjalankan inisialisasi layanan dasar, lalu melanjutkan ke Home Screen
/// setelah tampilan pembuka terlihat setidaknya selama waktu minimum.
class SplashScreen extends StatefulWidget {
  static const Duration minimumDisplayDuration = Duration(milliseconds: 1500);

  final AppInitializer initializer;
  final TtsService? ttsService;
  final SpeechToTextService? speechToTextService;
  final VoidCallback? onInitialized;
  final bool navigateToHome;

  const SplashScreen({
    super.key,
    this.initializer = const AppInitializer(),
    this.ttsService,
    this.speechToTextService,
    this.onInitialized,
    this.navigateToHome = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitializing = false;
  String? _errorMessage;
  bool _isNavigating = false;
  final Stopwatch _displayStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _displayStopwatch.start();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    if (!mounted || _isInitializing) return;
    _isInitializing = true;

    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await widget.initializer.initialize();
      if (!mounted) return;

      if (!result.isSuccess) {
        setState(() {
          _errorMessage = result.errorMessage;
        });
        return;
      }
      _notifyInitialized();
      await _waitForMinimumDisplayDuration();
      if (!mounted) return;

      if (widget.navigateToHome) _navigateToHome();
    } catch (error, stackTrace) {
      debugPrint('SplashScreen initialization flow error: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Gagal menyiapkan aplikasi. Sentuh coba lagi untuk mengulang.';
      });
    } finally {
      _isInitializing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _waitForMinimumDisplayDuration() async {
    final remaining =
        SplashScreen.minimumDisplayDuration - _displayStopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  void _notifyInitialized() {
    try {
      widget.onInitialized?.call();
    } catch (error, stackTrace) {
      debugPrint(
        'SplashScreen onInitialized callback error: $error\n$stackTrace',
      );
    }
  }

  void _navigateToHome() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(
            speechToTextService: widget.speechToTextService,
            ttsService: widget.ttsService,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Ikon / Badge Identitas Aplikasi Daily Horizon
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Image.asset(
                  'assets/images/daily_horizon_icon.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),

              // Nama Aplikasi
              Semantics(
                header: true,
                child: Text(
                  'DailyBrief',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Tagline
              Text(
                'Temukan Informasi dalam Satu Sentuhan',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),

              const Spacer(flex: 2),

              // Status Inisialisasi: Error vs Indikator Loading
              if (_errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isInitializing
                              ? null
                              : _startInitialization,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Indikator Loading aktif selama proses inisialisasi hingga navigasi terjadi
                Semantics(
                  label: 'Memuat aplikasi',
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Menyiapkan informasi...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

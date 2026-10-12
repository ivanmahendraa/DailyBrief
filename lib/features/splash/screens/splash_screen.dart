import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/app_initializer.dart';
import '../../../services/preference_service.dart';
import '../../../services/tts_service.dart';
import '../../home/screens/home_screen.dart';

/// Halaman Splash Screen DailyBrief.
///
/// Menampilkan identitas aplikasi, logo/ikon, tagline, indikator pemuatan,
/// menjalankan inisialisasi layanan dasar (TASK-09), membacakan panduan awal
/// kunjungan pertama (TASK-21) atau sapaan kunjungan berikutnya (TASK-23) melalui
/// Text-to-Speech sebelum Home Screen ditampilkan, menyimpan status kunjungan pertama
/// menggunakan SharedPreferences hanya setelah sapaan selesai secara utuh (TASK-22, FR-02),
/// menunggu pemutaran selesai secara nyata tanpa penundaan tiruan (FR-01, FR-02),
/// serta langsung melanjutkan ke Home Screen jika terjadi kegagalan TTS (TASK-10, TASK-21).
class SplashScreen extends StatefulWidget {
  final AppInitializer initializer;
  final TtsService? ttsService;
  final PreferenceService? preferenceService;
  final VoidCallback? onInitialized;
  final void Function(TtsPlaybackResult result)? onGreetingCompleted;
  final bool navigateToHome;

  const SplashScreen({
    super.key,
    this.initializer = const AppInitializer(),
    this.ttsService,
    this.preferenceService,
    this.onInitialized,
    this.onGreetingCompleted,
    this.navigateToHome = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final TtsService _ttsService;
  late final PreferenceService _preferenceService;
  String? _errorMessage;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _ttsService = widget.ttsService ?? TtsService();
    _preferenceService = widget.preferenceService ?? PreferenceService();
    _startInitialization();
  }

  @override
  void dispose() {
    // Hanya hentikan TTS jika SplashScreen di-dispose secara prematur
    // (misalnya aplikasi ditutup sebelum navigasi ke HomeScreen berlangsung).
    // Jika navigasi ke HomeScreen sedang berlangsung (_isNavigating == true),
    // jangan panggil stop() agar tidak memotong sapaan kedua di HomeScreen.
    if (!_isNavigating && _ttsService.isSpeaking) {
      _ttsService.stop();
    }
    super.dispose();
  }

  Future<void> _startInitialization() async {
    if (!mounted) return;

    setState(() {
      _errorMessage = null;
      _isNavigating = false;
    });

    final result = await widget.initializer.initialize();

    if (!mounted) return;

    if (result.isSuccess) {
      widget.onInitialized?.call();

      // TASK-21, TASK-22, TASK-23: Membacakan sapaan kunjungan pertama atau kunjungan berikutnya
      // pada Splash Screen sebelum Home Screen ditampilkan, menunggu pemutaran sapaan selesai
      // secara nyata sebelum navigasi ke Home Screen, dan langsung melanjutkan jika terjadi kegagalan.
      await _playGreetingFlow();

      if (!mounted) return;

      if (widget.navigateToHome && !_isNavigating) {
        _navigateToHome();
      }
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
      });
    }
  }

  Future<void> _playGreetingFlow() async {
    final isFirstVisit = await _preferenceService.isFirstVisit();
    final greetingText = isFirstVisit
        ? AppStrings.firstVisitGreeting
        : AppStrings.returningVisitGreeting;

    try {
      final playbackResult = await _ttsService.speak(greetingText);

      // FR-02, TASK-22: Status kunjungan pertama hanya diperbarui sebagai berhasil
      // setelah sapaan pertama berhasil selesai diputar secara utuh.
      if (playbackResult.isSuccess && isFirstVisit) {
        await _preferenceService.markFirstVisitCompleted();
      }

      widget.onGreetingCompleted?.call(playbackResult);
    } catch (error) {
      debugPrint('SplashScreen TTS greeting playback error: $error');
      widget.onGreetingCompleted?.call(
        TtsPlaybackResult.failure('Gagal memutar sapaan: $error'),
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
          builder: (_) => HomeScreen(ttsService: _ttsService),
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
                  border: Border.all(
                    color: AppColors.border,
                    width: 1.5,
                  ),
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
                          onPressed: _startInitialization,
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
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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

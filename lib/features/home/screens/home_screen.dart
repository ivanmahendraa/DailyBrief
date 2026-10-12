import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/tts_service.dart';

/// Halaman Utama (Home Screen) DailyBrief dengan konsep Daily Horizon.
///
/// Menyediakan antarmuka yang tenang, bersih, kontras tinggi, dan ramah aksesibilitas:
/// - Header dengan simbol Daily Horizon dan nama aplikasi DailyBrief.
/// - Status interaksi awal ("Siap Digunakan").
/// - Area interaksi utama yang diperbesar dengan pengikatan event sentuh (onTap)
///   dan umpan balik getaran haptik (HapticFeedback, TASK-14, TASK-25).
/// - Petunjuk daftar perintah suara di bagian bawah.
/// - Pemutaran sapaan suara pengantar ("Temukan informasi dalam satu sentuhan.") sekali
///   setelah Home Screen terbuka.
class HomeScreen extends StatefulWidget {
  final TtsService? ttsService;
  final void Function(TtsPlaybackResult result)? onGreetingCompleted;
  final VoidCallback? onTouchAreaTap;

  const HomeScreen({
    super.key,
    this.ttsService,
    this.onGreetingCompleted,
    this.onTouchAreaTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TtsService _ttsService;
  bool _hasSpokenGreeting = false;

  @override
  void initState() {
    super.initState();
    _ttsService = widget.ttsService ?? TtsService();
    _playGreeting();
  }

  Future<void> _playGreeting() async {
    if (_hasSpokenGreeting) return;
    _hasSpokenGreeting = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final result = await _ttsService.speak(AppStrings.homeGreeting);
        if (!mounted) return;
        widget.onGreetingCompleted?.call(result);
      } catch (error) {
        debugPrint('HomeScreen TTS greeting playback error: $error');
        if (!mounted) return;
        widget.onGreetingCompleted?.call(
          TtsPlaybackResult.failure('Gagal memutar sapaan Home: $error'),
        );
      }
    });
  }

  Future<void> _handleTouchAreaTap() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (error) {
      debugPrint('HomeScreen HapticFeedback error: $error');
    }
    widget.onTouchAreaTap?.call();
  }

  @override
  void dispose() {
    if (_ttsService.isSpeaking) {
      _ttsService.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/daily_horizon_icon.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              semanticLabel: 'Simbol Daily Horizon',
            ),
            const SizedBox(width: 10),
            Text(
              AppStrings.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Status Interaksi Awal: Siap Digunakan
              Center(
                child: Semantics(
                  label: 'Status interaksi: ${AppStrings.statusReady}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.statusReady,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Area Interaksi Utama yang Diperbesar (Visual Focus & Interaksi Sentuh)
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Area interaksi utama',
                  hint: AppStrings.touchAreaSubtitle,
                  child: Material(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _handleTouchAreaTap,
                      splashColor: AppColors.primaryContainer.withOpacity(0.5),
                      highlightColor: AppColors.primaryContainer.withOpacity(0.2),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 32,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Ikon Visual Utama Diperbesar
                                  Container(
                                    width: 124,
                                    height: 124,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.secondary,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.mic_none_rounded,
                                      size: 64,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Judul Area Diperbesar
                                  Text(
                                    AppStrings.touchAreaTitle,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Subtitle / Petunjuk
                                  Text(
                                    AppStrings.touchAreaSubtitle,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Petunjuk Contoh Perintah Suara
              Semantics(
                label: AppStrings.commandHints,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    AppStrings.commandHints,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

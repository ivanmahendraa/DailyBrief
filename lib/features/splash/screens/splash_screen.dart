import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/speech_to_text_service.dart';
import '../../../services/tts_service.dart';
import '../../home/screens/home_screen.dart';
import '../../voice/voice_controller.dart';

/// Menampilkan splash screen sebelum beralih ke [HomeScreen].
class SplashScreen extends StatefulWidget {
  final TtsService? ttsService;
  final SpeechToTextService? speechToTextService;
  final VoiceController? voiceController;

  const SplashScreen({
    super.key,
    this.ttsService,
    this.speechToTextService,
    this.voiceController,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToHome());
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(
          speechToTextService: widget.speechToTextService,
          ttsService: widget.ttsService,
          voiceController: widget.voiceController,
        ),
      ),
    );
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

              // Indikator loading ditampilkan selama frame splash pertama.
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

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

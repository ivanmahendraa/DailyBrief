import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/screens/splash_screen.dart';
import 'services/tts_service.dart';

/// Root widget aplikasi DailyBrief.
///
/// Mengatur konfigurasi dasar [MaterialApp], tema global dari [AppTheme],
/// serta layar awal Splash Screen (TASK-08, TASK-21).
class DailyBriefApp extends StatelessWidget {
  final TtsService? ttsService;

  const DailyBriefApp({super.key, this.ttsService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DailyBrief',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SplashScreen(ttsService: ttsService),
    );
  }
}


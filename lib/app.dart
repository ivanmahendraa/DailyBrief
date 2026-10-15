import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/splash/screens/splash_screen.dart';
import 'services/speech_to_text_service.dart';
import 'services/tts_service.dart';

/// Root widget aplikasi DailyBrief.
///
/// Mengatur konfigurasi dasar [MaterialApp], tema global dari [AppTheme],
/// serta layar awal Splash Screen (TASK-08, TASK-21).
class DailyBriefApp extends StatefulWidget {
  final TtsService? ttsService;
  final SpeechToTextService? speechToTextService;

  const DailyBriefApp({super.key, this.ttsService, this.speechToTextService});

  @override
  State<DailyBriefApp> createState() => _DailyBriefAppState();
}

class _DailyBriefAppState extends State<DailyBriefApp> {
  late final TtsService _ttsService = widget.ttsService ?? TtsService();
  late final SpeechToTextService _speechToTextService =
      widget.speechToTextService ?? SpeechToTextService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DailyBrief',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SplashScreen(
        ttsService: _ttsService,
        speechToTextService: _speechToTextService,
      ),
    );
  }
}

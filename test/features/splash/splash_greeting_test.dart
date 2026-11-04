import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/features/home/screens/home_screen.dart';
import 'package:daily_brief/features/splash/screens/splash_screen.dart';
import 'package:daily_brief/services/app_initializer.dart';
import 'package:daily_brief/services/tts_service.dart';

class _ControlledFakeInitializer extends AppInitializer {
  final Completer<InitializationResult> _completer =
      Completer<InitializationResult>();

  void completeSuccess() {
    _completer.complete(InitializationResult.success());
  }

  @override
  Future<InitializationResult> initialize() => _completer.future;
}

class _RecordingTtsService extends TtsService {
  final List<String> spokenTexts = [];

  @override
  Future<TtsPlaybackResult> speak(String text) async {
    spokenTexts.add(text);
    return TtsPlaybackResult.success();
  }
}

class _ThrowingTtsService extends TtsService {
  @override
  Future<TtsPlaybackResult> speak(String text) async {
    throw StateError('TTS unavailable');
  }
}

void main() {
  group('Splash dan sapaan Home', () {
    testWidgets(
      'Splash menunggu inisialisasi lalu langsung membuka Home tanpa jeda tiruan',
      (WidgetTester tester) async {
        final initializer = _ControlledFakeInitializer();
        final ttsService = _RecordingTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: SplashScreen(
              initializer: initializer,
              ttsService: ttsService,
            ),
          ),
        );

        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.text('DailyBrief'), findsOneWidget);
        expect(
          find.text('Temukan Informasi dalam Satu Sentuhan'),
          findsOneWidget,
        );
        expect(ttsService.spokenTexts, isEmpty);

        initializer.completeSuccess();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(ttsService.spokenTexts, [AppStrings.welcomeGreeting]);
      },
    );

    testWidgets('TTS sapaan gagal tetapi Home tetap dapat digunakan', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(ttsService: _ThrowingTtsService())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(AppStrings.statusReady), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

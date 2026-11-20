import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/app.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/features/home/screens/home_screen.dart';
import 'package:daily_brief/features/splash/screens/splash_screen.dart';
import 'package:daily_brief/services/speech_to_text_service.dart';
import 'package:daily_brief/services/tts_service.dart';

const _accessibilityShortcutChannel = MethodChannel(
  'dailybrief/accessibility_shortcut',
);

void _mockAccessibilityShortcutChannel(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _accessibilityShortcutChannel,
    (call) async => call.method == 'consumePendingShortcut' ? false : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _accessibilityShortcutChannel,
      null,
    ),
  );
}

/// Fake implementation of [TtsClient] yang segera menyelesaikan pemutaran suara
/// untuk mendukung pengujian kontrol navigasi widget secara deterministik.
class _ImmediateFakeTtsClient implements TtsClient {
  VoidCallback? _completionHandler;
  final List<String> spokenTexts = [];

  @override
  Future<dynamic> isLanguageAvailable(String language) async => true;

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> speak(String text) async {
    spokenTexts.add(text);
    Future.microtask(() => _completionHandler?.call());
    return 1;
  }

  @override
  Future<dynamic> stop() async => 1;

  @override
  void setStartHandler(VoidCallback callback) {}

  @override
  void setCompletionHandler(VoidCallback callback) {
    _completionHandler = callback;
  }

  @override
  void setErrorHandler(void Function(dynamic message) callback) {}

  @override
  void setCancelHandler(VoidCallback callback) {}
}

class _AppFlowSpeechClient implements SpeechToTextClient {
  int listenCallCount = 0;
  void Function(String status)? onStatus;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message, bool isPermanent) onError,
  }) async {
    this.onStatus = onStatus;
    return true;
  }

  @override
  Future<List<SpeechLocale>> locales() async => const [
    SpeechLocale(localeId: 'id-ID', name: 'Indonesian'),
  ];

  @override
  Future<void> listen({
    required String? localeId,
    required SpeechResultCallback onResult,
  }) async {
    listenCallCount++;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

void main() {
  group('Splash Screen dan navigasi ke Home', () {
    late TtsService immediateTtsService;

    setUp(() {
      immediateTtsService = TtsService(client: _ImmediateFakeTtsClient());
    });

    testWidgets('1. Splash Screen ditampilkan pada awal peluncuran aplikasi', (
      WidgetTester tester,
    ) async {
      _mockAccessibilityShortcutChannel(tester);
      await tester.pumpWidget(DailyBriefApp(ttsService: immediateTtsService));

      // Verifikasi identitas dan komponen Splash Screen pada peluncuran
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('DailyBrief'), findsOneWidget);
      expect(
        find.text('Temukan Informasi dalam Satu Sentuhan'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Menyiapkan informasi...'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets(
      'TTS Service yang sama dipakai sapaan Home dan interaksi suara',
      (WidgetTester tester) async {
        _mockAccessibilityShortcutChannel(tester);
        final ttsClient = _ImmediateFakeTtsClient();
        final speechClient = _AppFlowSpeechClient();
        final ttsService = TtsService(client: ttsClient);

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (methodCall) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        await tester.pumpWidget(
          DailyBriefApp(
            ttsService: ttsService,
            speechToTextService: SpeechToTextService(client: speechClient),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(ttsClient.spokenTexts, [AppStrings.welcomeGreeting]);

        await tester.tap(find.byKey(const Key('touch_area_inkwell')));
        await tester.pump();
        while (speechClient.listenCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(ttsClient.spokenTexts, [
          AppStrings.welcomeGreeting,
          AppStrings.voiceConfirmation,
        ]);
        expect(speechClient.listenCallCount, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}

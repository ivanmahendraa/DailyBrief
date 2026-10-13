import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/core/theme/app_theme.dart';
import 'package:daily_brief/features/home/screens/home_screen.dart';
import 'package:daily_brief/services/tts_service.dart';

class _FakeTtsClient implements TtsClient {
  String? lastSpokenText;
  final List<String> spokenTexts = [];
  int speakCallCount = 0;
  bool stopped = false;
  VoidCallback? completionHandler;

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
    lastSpokenText = text;
    spokenTexts.add(text);
    speakCallCount++;
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopped = true;
    return 1;
  }

  @override
  void setStartHandler(VoidCallback callback) {}

  @override
  void setCompletionHandler(VoidCallback callback) {
    completionHandler = callback;
  }

  @override
  void setErrorHandler(void Function(dynamic message) callback) {}

  @override
  void setCancelHandler(VoidCallback callback) {}

  void triggerCompletion() {
    completionHandler?.call();
  }
}

void main() {
  group('TASK-12: Home Screen DailyBrief Tests', () {
    Widget buildTestableHomeScreen({
      TtsService? ttsService,
      void Function(TtsPlaybackResult result)? onGreetingCompleted,
      VoidCallback? onTouchAreaTap,
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(
          ttsService: ttsService ?? TtsService(client: _FakeTtsClient()),
          onGreetingCompleted: onGreetingCompleted,
          onTouchAreaTap: onTouchAreaTap,
        ),
      );
    }

    testWidgets('1. Menampilkan nama aplikasi DailyBrief dan simbol Daily Horizon pada AppBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());

      // AppBar harus menampilkan nama aplikasi 'DailyBrief' dan simbol Daily Horizon
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.bySemanticsLabel('Simbol Daily Horizon'), findsOneWidget);
    });

    testWidgets('2. Menampilkan status interaksi awal aplikasi siap digunakan',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());

      // Indikator status interaksi awal 'Siap Digunakan'
      expect(find.text(AppStrings.statusReady), findsOneWidget);

      // Memiliki label semantik untuk pembaca layar
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Status interaksi: ${AppStrings.statusReady}',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        '3. Memastikan teks petunjuk lama telah dihapus dari bawah status siap digunakan',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());

      // Teks panduan lama yang sudah tidak digunakan telah dihapus
      expect(
        find.text('Sentuh area utama layar untuk mulai bertanya.'),
        findsNothing,
      );
    });

    testWidgets(
        '4. Menampilkan area interaksi utama yang diperbesar dengan ikon mikrofon dan petunjuk yang jelas',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());

      // Menampilkan judul dan petunjuk area sentuh
      expect(find.text(AppStrings.touchAreaTitle), findsOneWidget);
      expect(find.text(AppStrings.touchAreaSubtitle), findsOneWidget);

      // Menampilkan ikon visual mikrofon dengan ukuran diperbesar (size: 64)
      final micIconFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.mic_none_rounded &&
            widget.size == 64,
      );
      expect(micIconFinder, findsOneWidget);

      // Memastikan area interaksi utama memiliki konfigurasi semantik yang tepat
      final touchAreaSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Area interaksi utama' &&
            widget.properties.button == true,
      );
      expect(touchAreaSemantics, findsOneWidget);
    });

    testWidgets(
        '5. Menampilkan petunjuk contoh perintah suara pada bagian bawah',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());

      expect(find.text(AppStrings.commandHints), findsOneWidget);
    });

    testWidgets(
        '6. Responsif dan tidak mengalami RenderFlex overflow pada ukuran layar kecil',
        (WidgetTester tester) async {
      // Simulasikan layar kecil (misalnya perangkat berdimensi 320 x 480)
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      // Tidak ada error luapan (overflow) yang terlempar
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.statusReady), findsOneWidget);
    });

    testWidgets(
        '7. Responsif pada ukuran layar standar dan lanskap',
        (WidgetTester tester) async {
      // Simulasikan orientasi lanskap (800 x 400)
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(AppStrings.appName), findsOneWidget);
    });

    testWidgets(
        '8. Memutar pesan suara kedua setelah Home Screen terbuka',
        (WidgetTester tester) async {
      final fakeClient = _FakeTtsClient();
      final ttsService = TtsService(client: fakeClient);

      await tester.pumpWidget(buildTestableHomeScreen(ttsService: ttsService));
      await tester.pumpAndSettle();

      expect(fakeClient.speakCallCount, 1);
      expect(fakeClient.lastSpokenText, AppStrings.homeGreeting);
      expect(
        fakeClient.lastSpokenText,
        'Temukan informasi dalam satu sentuhan.',
      );
    });

    testWidgets(
        '9. Pesan kedua tidak diputar berulang akibat rebuild widget',
        (WidgetTester tester) async {
      final fakeClient = _FakeTtsClient();
      final ttsService = TtsService(client: fakeClient);

      await tester.pumpWidget(buildTestableHomeScreen(ttsService: ttsService));
      await tester.pumpAndSettle();

      expect(fakeClient.speakCallCount, 1);

      // Picu rebuild widget
      await tester.pumpWidget(buildTestableHomeScreen(ttsService: ttsService));
      await tester.pump();
      await tester.pumpAndSettle();

      // Jumlah pemanggilan speak tetap 1 (tidak berulang)
      expect(fakeClient.speakCallCount, 1);
      expect(fakeClient.spokenTexts.length, 1);
    });

    testWidgets(
        '10. Menunggu callback penyelesaian suara asli dari engine TTS',
        (WidgetTester tester) async {
      final fakeClient = _FakeTtsClient();
      final ttsService = TtsService(client: fakeClient);
      TtsPlaybackResult? completionResult;

      await tester.pumpWidget(
        buildTestableHomeScreen(
          ttsService: ttsService,
          onGreetingCompleted: (result) {
            completionResult = result;
          },
        ),
      );

      // Frame awal dipompa
      await tester.pump();

      // Sapaan kedua mulai dipanggil
      expect(fakeClient.speakCallCount, 1);
      expect(fakeClient.lastSpokenText, AppStrings.homeGreeting);

      // Sebelum callback penyelesaian TTS selesai, completionResult masih null
      expect(completionResult, isNull);

      // Simulasikan event completion handler dari engine native
      fakeClient.triggerCompletion();
      await tester.pumpAndSettle();

      // Setelah event completion native diterima, callback penyelesaian mengembalikan success
      expect(completionResult, isNotNull);
      expect(completionResult!.isSuccess, isTrue);
    });

    testWidgets(
        '11. Menghentikan pemutaran audio jika HomeScreen di-dispose sebelum selesai',
        (WidgetTester tester) async {
      final fakeClient = _FakeTtsClient();
      final ttsService = TtsService(client: fakeClient);

      await tester.pumpWidget(buildTestableHomeScreen(ttsService: ttsService));
      await tester.pump();

      expect(ttsService.isSpeaking, isTrue);

      // Pengguna meninggalkan halaman (HomeScreen di-dispose)
      await tester.pumpWidget(const SizedBox.shrink());

      // Audio dihentikan agar tidak menggantung
      expect(fakeClient.stopped, isTrue);
    });

    testWidgets(
        '12. Menekan area sentuh utama memanggil callback onTouchAreaTap (TASK-25)',
        (WidgetTester tester) async {
      int tapCount = 0;

      // Fake TTS client yang langsung menyelesaikan speak() via microtask
      // sehingga greeting selesai dan pumpAndSettle() tidak menggantung
      final autoClient = _FakeTtsClient();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          ttsService: TtsService(client: autoClient),
          onTouchAreaTap: () => tapCount++,
        ),
      );

      // Selesaikan greeting awal HomeScreen
      await tester.pump(); // frame pertama (postFrameCallback)
      autoClient.triggerCompletion(); // simulasikan TTS selesai
      await tester.pump(); // proses completion

      // Setup mock HapticFeedback channel agar await-nya resolve di test environment
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async => null,
      );

      // Temukan InkWell area sentuh via Key yang terdaftar
      final inkWellFinder = find.byKey(const Key('touch_area_inkwell'));
      expect(inkWellFinder, findsOneWidget);

      // Ketuk area sentuh
      await tester.tap(inkWellFinder);
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 50));

      // Callback onTouchAreaTap harus dipanggil tepat sekali
      expect(tapCount, equals(1));

      // Cleanup mock
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets(
        '13. Area sentuh tetap merespons dengan haptic meski onTouchAreaTap null',
        (WidgetTester tester) async {
      // onTouchAreaTap tidak diteruskan (null) — perilaku default sebelum VoiceController terpasang
      final autoClient = _FakeTtsClient();

      await tester.pumpWidget(
        buildTestableHomeScreen(
          ttsService: TtsService(client: autoClient),
        ),
      );

      // Selesaikan greeting awal
      await tester.pump();
      autoClient.triggerCompletion();
      await tester.pump();

      // Setup mock HapticFeedback channel
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async => null,
      );

      // Temukan InkWell area sentuh via Key
      final inkWellFinder = find.byKey(const Key('touch_area_inkwell'));
      expect(inkWellFinder, findsOneWidget);

      // Ketuk tidak boleh throw exception meski callback null
      await tester.tap(inkWellFinder);
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 50));

      // Tidak ada exception = null-safe callback berjalan dengan benar
      expect(tester.takeException(), isNull);

      // Cleanup mock
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/core/theme/app_theme.dart';
import 'package:daily_brief/features/home/screens/home_screen.dart';
import 'package:daily_brief/features/voice/voice_controller.dart';
import 'package:daily_brief/services/speech_to_text_service.dart';
import 'package:daily_brief/services/tts_service.dart';

class _FakeVoiceController extends VoiceController {
  VoiceInteractionState currentState = VoiceInteractionState.idle;
  String? currentErrorMessage;
  int startActionCount = 0;

  @override
  VoiceInteractionState get state => currentState;

  @override
  String? get errorMessage => currentErrorMessage;

  @override
  Future<void> handleUserTap() async {
    startActionCount++;
  }

  void emitState(VoiceInteractionState newState, {String? errorMessage}) {
    currentState = newState;
    currentErrorMessage = errorMessage;
    notifyListeners();
  }
}

class _SingletonSpeechToTextClient implements SpeechToTextClient {
  _SingletonSpeechToTextClient(this.events);

  final List<String> events;
  bool _initialized = false;
  int listenCallCount = 0;
  void Function(String status)? _statusListener;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message, bool isPermanent) onError,
  }) async {
    if (_initialized) return true;
    _initialized = true;
    _statusListener = onStatus;
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
    events.add('stt-listen');
    listenCallCount++;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  void emitStatus(String status) => _statusListener?.call(status);
}

class _ImmediateTtsService extends TtsService {
  _ImmediateTtsService(this.events) : super();

  final List<String> events;

  @override
  bool get isReady => true;

  @override
  Future<TtsPlaybackResult> speak(String text) async {
    events.add('tts-confirmation');
    return TtsPlaybackResult.success();
  }
}

class _HomeGreetingTtsService extends TtsService {
  final List<String> spokenTexts = [];

  @override
  Future<TtsPlaybackResult> speak(String text) async {
    spokenTexts.add(text);
    return TtsPlaybackResult.success();
  }
}

void main() {
  group('TASK-12: Home Screen DailyBrief Tests', () {
    late _HomeGreetingTtsService greetingTtsService;

    setUp(() {
      greetingTtsService = _HomeGreetingTtsService();
    });

    Widget buildTestableHomeScreen({
      VoidCallback? onTouchAreaTap,
      VoiceController? voiceController,
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(
          onTouchAreaTap: onTouchAreaTap,
          voiceController: voiceController ?? _FakeVoiceController(),
          ttsService: greetingTtsService,
        ),
      );
    }

    testWidgets(
      '1. Menampilkan nama aplikasi DailyBrief dan simbol Daily Horizon pada AppBar',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableHomeScreen());

        // AppBar harus menampilkan nama aplikasi 'DailyBrief' dan simbol Daily Horizon
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text(AppStrings.appName), findsOneWidget);
        expect(find.bySemanticsLabel('Simbol Daily Horizon'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Menampilkan status interaksi awal aplikasi siap digunakan',
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
      },
    );

    testWidgets(
      '3. Memastikan teks petunjuk lama telah dihapus dari bawah status siap digunakan',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableHomeScreen());

        // Teks panduan lama yang sudah tidak digunakan telah dihapus
        expect(
          find.text('Sentuh area utama layar untuk mulai bertanya.'),
          findsNothing,
        );
      },
    );

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
      },
    );

    testWidgets(
      '5. Menampilkan petunjuk contoh perintah suara pada bagian bawah',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableHomeScreen());

        expect(find.text(AppStrings.commandHints), findsOneWidget);
      },
    );

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
      },
    );

    testWidgets('7. Responsif pada ukuran layar standar dan lanskap', (
      WidgetTester tester,
    ) async {
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

    testWidgets('8. Greeting Home hanya berjalan sekali saat rebuild', (
      WidgetTester tester,
    ) async {
      final controller = _FakeVoiceController();
      greetingTtsService.spokenTexts.clear();
      await tester.pumpWidget(
        buildTestableHomeScreen(voiceController: controller),
      );
      await tester.pump();
      await tester.pumpWidget(
        buildTestableHomeScreen(voiceController: controller),
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(greetingTtsService.spokenTexts, [AppStrings.welcomeGreeting]);
      expect(controller.startActionCount, 0);
      expect(tester.takeException(), isNull);
    });

    test(
      'Controller kedua menerima status melalui STT service yang sama',
      () async {
        final events = <String>[];
        final sharedClient = _SingletonSpeechToTextClient(events);
        final sharedService = SpeechToTextService(client: sharedClient);
        final firstController = VoiceController(
          speechToTextService: sharedService,
          ttsService: _ImmediateTtsService(events),
        );

        final firstStart = firstController.startListening();
        while (sharedClient.listenCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        sharedClient.emitStatus('listening');
        await firstStart;
        expect(firstController.state, VoiceInteractionState.listening);
        expect(sharedClient.listenCallCount, 1);
        expect(events, ['tts-confirmation', 'stt-listen']);

        firstController.dispose();
        await Future<void>.delayed(Duration.zero);

        final secondController = VoiceController(
          speechToTextService: sharedService,
          ttsService: _ImmediateTtsService(events),
        );

        final secondStart = secondController.startListening();
        while (sharedClient.listenCallCount == 1) {
          await Future<void>.delayed(Duration.zero);
        }
        sharedClient.emitStatus('listening');
        await secondStart;

        expect(secondController.state, VoiceInteractionState.listening);
        expect(sharedClient.listenCallCount, 2);
        expect(events, [
          'tts-confirmation',
          'stt-listen',
          'tts-confirmation',
          'stt-listen',
        ]);
        secondController.dispose();
      },
    );

    testWidgets('Haptic, konfirmasi TTS, baru kemudian memulai STT', (
      WidgetTester tester,
    ) async {
      final events = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method != 'HapticFeedback.vibrate') return null;
          events.add('haptic');
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final client = _SingletonSpeechToTextClient(events);
      final controller = VoiceController(
        speechToTextService: SpeechToTextService(client: client),
        ttsService: _ImmediateTtsService(events),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            voiceController: controller,
            ttsService: _HomeGreetingTtsService(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('touch_area_inkwell')));
      await tester.pump();
      while (client.listenCallCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(events, ['haptic', 'tts-confirmation', 'stt-listen']);
      client.emitStatus('listening');
      await tester.pump();
      expect(find.text('Mendengarkan'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('STT tetap dimulai jika haptic tidak tersedia', (
      WidgetTester tester,
    ) async {
      final events = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method != 'HapticFeedback.vibrate') return null;
          events.add('haptic');
          throw PlatformException(code: 'haptic_unavailable');
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final client = _SingletonSpeechToTextClient(events);
      final controller = VoiceController(
        speechToTextService: SpeechToTextService(client: client),
        ttsService: _ImmediateTtsService(events),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            voiceController: controller,
            ttsService: _HomeGreetingTtsService(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('touch_area_inkwell')));
      await tester.pump();
      while (client.listenCallCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(events, ['haptic', 'tts-confirmation', 'stt-listen']);
      client.emitStatus('listening');
      await tester.pump();
      expect(find.text('Mendengarkan'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tap berulang selama haptic tertahan hanya memulai satu sesi', (
      WidgetTester tester,
    ) async {
      final events = <String>[];
      final hapticGate = Completer<void>();
      var hapticCallCount = 0;
      var acceptedTapCount = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) {
          if (methodCall.method != 'HapticFeedback.vibrate') {
            return Future<void>.value();
          }
          hapticCallCount++;
          events.add('haptic');
          return hapticGate.future;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final client = _SingletonSpeechToTextClient(events);
      final controller = VoiceController(
        speechToTextService: SpeechToTextService(client: client),
        ttsService: _ImmediateTtsService(events),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            voiceController: controller,
            onTouchAreaTap: () => acceptedTapCount++,
            ttsService: _HomeGreetingTtsService(),
          ),
        ),
      );
      final touchArea = find.byKey(const Key('touch_area_inkwell'));

      await tester.tap(touchArea);
      await tester.pump();
      await tester.tap(touchArea);
      await tester.pump();

      expect(hapticCallCount, 1);
      expect(client.listenCallCount, 0);

      hapticGate.complete();
      await tester.pump();
      while (client.listenCallCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(acceptedTapCount, 1);
      expect(events, ['haptic', 'tts-confirmation', 'stt-listen']);
      client.emitStatus('listening');
      await tester.pump();
      await tester.tap(touchArea);
      await tester.pump();
      expect(hapticCallCount, 1);
      expect(client.listenCallCount, 1);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'status Mendengarkan hanya tampil setelah controller berubah state',
      (WidgetTester tester) async {
        final controller = _FakeVoiceController();
        await tester.pumpWidget(
          buildTestableHomeScreen(voiceController: controller),
        );

        expect(find.text('Mendengarkan'), findsNothing);
        controller.emitState(VoiceInteractionState.listening);
        await tester.pump();

        expect(find.text('Mendengarkan'), findsOneWidget);
      },
    );

    testWidgets(
      'menampilkan pesan error yang dapat dibaca saat status kembali siap',
      (WidgetTester tester) async {
        const message = 'Izin mikrofon belum diberikan.';
        final controller = _FakeVoiceController();
        await tester.pumpWidget(
          buildTestableHomeScreen(voiceController: controller),
        );

        controller.emitState(VoiceInteractionState.idle, errorMessage: message);
        await tester.pump();

        expect(find.text(AppStrings.statusReady), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.liveRegion == true,
          ),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      '9. Menekan area sentuh utama memanggil callback onTouchAreaTap (TASK-25)',
      (WidgetTester tester) async {
        int tapCount = 0;
        final controller = _FakeVoiceController();

        await tester.pumpWidget(
          buildTestableHomeScreen(
            onTouchAreaTap: () => tapCount++,
            voiceController: controller,
          ),
        );

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
        expect(controller.startActionCount, 1);

        // Cleanup mock
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      },
    );

    testWidgets(
      '10. Area sentuh tetap merespons dengan haptic meski onTouchAreaTap null',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableHomeScreen());

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
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      },
    );
  });
}

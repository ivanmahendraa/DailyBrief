import 'dart:async';

import 'package:daily_brief/app.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/features/home/screens/home_screen.dart';
import 'package:daily_brief/features/voice/command_parser.dart';
import 'package:daily_brief/features/voice/voice_controller.dart';
import 'package:daily_brief/services/command_history_service.dart';
import 'package:daily_brief/services/date_time_service.dart';
import 'package:daily_brief/services/speech_to_text_service.dart';
import 'package:daily_brief/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FlowSpeechClient implements SpeechToTextClient {
  void Function(String status)? _statusListener;
  SpeechResultCallback? _resultCallback;
  int listenCallCount = 0;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message, bool isPermanent) onError,
  }) async {
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
    expect(localeId, 'id-ID');
    listenCallCount++;
    _resultCallback = onResult;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  void emitStatus(String status) => _statusListener?.call(status);

  void emitFinalResult(String words) {
    _resultCallback?.call(
      SpeechRecognitionResult(recognizedWords: words, isFinal: true),
    );
  }
}

class _FlowTtsService extends TtsService {
  final spokenTexts = <String>[];
  final confirmationCompletion = Completer<TtsPlaybackResult>();
  final responseCompletion = Completer<TtsPlaybackResult>();
  bool failGreeting = false;

  @override
  bool get isReady => true;

  @override
  Future<TtsPlaybackResult> speak(String text) {
    spokenTexts.add(text);
    if (text == AppStrings.welcomeGreeting && failGreeting) {
      return Future.value(TtsPlaybackResult.failure('TTS unavailable'));
    }
    if (text == AppStrings.voiceConfirmation) {
      return confirmationCompletion.future;
    }
    if (text.startsWith('Hari ini hari ')) {
      return responseCompletion.future;
    }
    return Future.value(TtsPlaybackResult.success());
  }
}

class _RecordingCommandHistoryWriter implements CommandHistoryWriter {
  final commands = <VoiceCommand>[];

  @override
  Future<void> record(VoiceCommand command) async {
    commands.add(command);
  }
}

void main() {
  group('DailyBrief end-to-end flow', () {
    testWidgets(
      'opens through splash, greets, listens, answers, and returns to ready',
      (tester) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        final speechClient = _FlowSpeechClient();
        final speechService = SpeechToTextService(client: speechClient);
        final ttsService = _FlowTtsService();
        final historyWriter = _RecordingCommandHistoryWriter();
        final voiceController = VoiceController(
          dateTimeService: DateTimeService(
            now: () => DateTime(2026, 10, 16, 15),
          ),
          speechToTextService: speechService,
          ttsService: ttsService,
          commandHistoryWriter: historyWriter,
        );

        await tester.pumpWidget(
          DailyBriefApp(
            speechToTextService: speechService,
            ttsService: ttsService,
            voiceController: voiceController,
          ),
        );

        expect(
          find.text('Temukan Informasi dalam Satu Sentuhan'),
          findsOneWidget,
        );
        expect(ttsService.spokenTexts, isEmpty);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(ttsService.spokenTexts, [AppStrings.welcomeGreeting]);
        expect(find.text(AppStrings.statusReady), findsOneWidget);

        await tester.tap(find.byKey(const Key('touch_area_inkwell')));
        await tester.pump();
        await tester.pump();
        expect(ttsService.spokenTexts, contains(AppStrings.voiceConfirmation));
        expect(find.text(AppStrings.statusConfirming), findsOneWidget);
        expect(ttsService.spokenTexts.last, AppStrings.voiceConfirmation);

        ttsService.confirmationCompletion.complete(TtsPlaybackResult.success());
        await tester.pump();
        await tester.pump();
        expect(speechClient.listenCallCount, 1);

        speechClient.emitStatus('listening');
        await tester.pump();
        expect(find.text('Mendengarkan'), findsOneWidget);

        speechClient.emitFinalResult('hari');
        await tester.pump();
        expect(find.text('Memproses'), findsOneWidget);

        speechClient.emitStatus('done');
        await tester.pump();
        await tester.pump();
        expect(find.text('Berbicara'), findsOneWidget);
        expect(ttsService.spokenTexts, [
          AppStrings.welcomeGreeting,
          AppStrings.voiceConfirmation,
          'Hari ini hari Jumat.',
        ]);
        expect(historyWriter.commands, [VoiceCommand.day]);

        ttsService.responseCompletion.complete(TtsPlaybackResult.success());
        await tester.pump();
        await tester.pump();
        expect(find.text(AppStrings.statusReady), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('continues to usable Home when the welcome TTS fails', (
      tester,
    ) async {
      final speechService = SpeechToTextService(client: _FlowSpeechClient());
      final ttsService = _FlowTtsService()..failGreeting = true;
      final voiceController = VoiceController(
        speechToTextService: speechService,
        ttsService: ttsService,
        commandHistoryWriter: _RecordingCommandHistoryWriter(),
      );

      await tester.pumpWidget(
        DailyBriefApp(
          speechToTextService: speechService,
          ttsService: ttsService,
          voiceController: voiceController,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(AppStrings.statusReady), findsOneWidget);
      expect(ttsService.spokenTexts, [AppStrings.welcomeGreeting]);
      expect(tester.takeException(), isNull);
    });
  });
}

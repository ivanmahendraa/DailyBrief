import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/features/home/screens/home_screen.dart';
import 'package:daily_brief/features/splash/screens/splash_screen.dart';
import 'package:daily_brief/services/app_initializer.dart';
import 'package:daily_brief/services/tts_service.dart';

class _FakeTtsClient implements TtsClient {
  final List<String> spokenTexts = [];
  int speakCallCount = 0;
  int stopCallCount = 0;

  VoidCallback? startHandler;
  VoidCallback? completionHandler;
  void Function(dynamic message)? errorHandler;
  VoidCallback? cancelHandler;

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
    speakCallCount++;
    spokenTexts.add(text);
    startHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCallCount++;
    cancelHandler?.call();
    return 1;
  }

  @override
  void setStartHandler(VoidCallback callback) => startHandler = callback;

  @override
  void setCompletionHandler(VoidCallback callback) =>
      completionHandler = callback;

  @override
  void setErrorHandler(void Function(dynamic message) callback) =>
      errorHandler = callback;

  @override
  void setCancelHandler(VoidCallback callback) => cancelHandler = callback;

  void completePlayback() => completionHandler?.call();

  void failPlayback(String message) => errorHandler?.call(message);

  void cancelPlayback() => cancelHandler?.call();
}

class _ThrowingTtsService extends TtsService {
  _ThrowingTtsService() : super(client: _FakeTtsClient());

  @override
  Future<TtsPlaybackResult> speak(String text) async {
    throw StateError('Unexpected speak exception');
  }
}

class _ControlledFakeInitializer extends AppInitializer {
  Completer<InitializationResult> _completer =
      Completer<InitializationResult>();
  int initializeCallCount = 0;

  @override
  Future<InitializationResult> initialize() {
    initializeCallCount++;
    return _completer.future;
  }

  void completeSuccess() {
    if (!_completer.isCompleted) {
      _completer.complete(InitializationResult.success());
    }
  }

  void completeFailure(String message) {
    if (!_completer.isCompleted) {
      _completer.complete(InitializationResult.failure(message));
    }
  }

  void reset() {
    _completer = Completer<InitializationResult>();
  }
}

class _TrackingNavigatorObserver extends NavigatorObserver {
  int replaceCount = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaceCount++;
  }
}

Widget _buildSplash({
  required AppInitializer initializer,
  required TtsService ttsService,
  bool navigateToHome = true,
  void Function(TtsPlaybackResult result)? onGreetingCompleted,
  VoidCallback? onInitialized,
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return MaterialApp(
    navigatorObservers: navigatorObservers,
    home: SplashScreen(
      initializer: initializer,
      ttsService: ttsService,
      navigateToHome: navigateToHome,
      onGreetingCompleted: onGreetingCompleted,
      onInitialized: onInitialized,
    ),
  );
}

void main() {
  group('Splash greeting and navigation', () {
    testWidgets(
      'memutar tepat satu greeting lalu membuka Home tanpa TTS kedua',
      (WidgetTester tester) async {
        final fakeClient = _FakeTtsClient();
        final ttsService = TtsService(client: fakeClient);
        final initializer = _ControlledFakeInitializer();
        final observer = _TrackingNavigatorObserver();

        await tester.pumpWidget(
          _buildSplash(
            initializer: initializer,
            ttsService: ttsService,
            navigatorObservers: [observer],
          ),
        );
        initializer.completeSuccess();
        await tester.pump();

        expect(fakeClient.speakCallCount, 1);
        expect(fakeClient.spokenTexts, [AppStrings.splashGreeting]);
        expect(find.byType(HomeScreen), findsNothing);

        fakeClient.completePlayback();
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(observer.replaceCount, 1);
        expect(fakeClient.speakCallCount, 1);
        expect(fakeClient.spokenTexts, [AppStrings.splashGreeting]);

        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        expect(fakeClient.speakCallCount, 1);
      },
    );

    testWidgets('menggunakan teks greeting yang sama pada pembukaan berulang', (
      WidgetTester tester,
    ) async {
      final fakeClient = _FakeTtsClient();
      final ttsService = TtsService(client: fakeClient);
      final firstInitializer = _ControlledFakeInitializer();

      await tester.pumpWidget(
        _buildSplash(initializer: firstInitializer, ttsService: ttsService),
      );
      firstInitializer.completeSuccess();
      await tester.pump();
      fakeClient.completePlayback();
      await tester.pumpAndSettle();

      final nextInitializer = _ControlledFakeInitializer();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _buildSplash(initializer: nextInitializer, ttsService: ttsService),
      );
      nextInitializer.completeSuccess();
      await tester.pump();

      expect(fakeClient.spokenTexts, [
        AppStrings.splashGreeting,
        AppStrings.splashGreeting,
      ]);

      fakeClient.completePlayback();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'TTS error callback tetap membuka Home dan melaporkan failure',
      (WidgetTester tester) async {
        final fakeClient = _FakeTtsClient();
        final initializer = _ControlledFakeInitializer();
        TtsPlaybackResult? callbackResult;
        var callbackCount = 0;

        await tester.pumpWidget(
          _buildSplash(
            initializer: initializer,
            ttsService: TtsService(client: fakeClient),
            onGreetingCompleted: (result) {
              callbackCount++;
              callbackResult = result;
            },
          ),
        );
        initializer.completeSuccess();
        await tester.pump();
        fakeClient.failPlayback('Audio device error');
        await tester.pumpAndSettle();

        expect(callbackResult?.isFailure, isTrue);
        expect(callbackCount, 1);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(fakeClient.speakCallCount, 1);
      },
    );

    testWidgets('TTS cancel tetap membuka Home dan melaporkan cancelled', (
      WidgetTester tester,
    ) async {
      final fakeClient = _FakeTtsClient();
      final initializer = _ControlledFakeInitializer();
      TtsPlaybackResult? callbackResult;

      await tester.pumpWidget(
        _buildSplash(
          initializer: initializer,
          ttsService: TtsService(client: fakeClient),
          onGreetingCompleted: (result) => callbackResult = result,
        ),
      );
      initializer.completeSuccess();
      await tester.pump();
      fakeClient.cancelPlayback();
      await tester.pumpAndSettle();

      expect(callbackResult?.isCancelled, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(fakeClient.speakCallCount, 1);
    });

    testWidgets('exception dari speak tetap membuka Home', (
      WidgetTester tester,
    ) async {
      final initializer = _ControlledFakeInitializer();
      TtsPlaybackResult? callbackResult;

      await tester.pumpWidget(
        _buildSplash(
          initializer: initializer,
          ttsService: _ThrowingTtsService(),
          onGreetingCompleted: (result) => callbackResult = result,
        ),
      );
      initializer.completeSuccess();
      await tester.pumpAndSettle();

      expect(callbackResult?.isFailure, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
      'exception callback observasi tidak mengubah hasil atau menghambat navigasi',
      (WidgetTester tester) async {
        final fakeClient = _FakeTtsClient();
        final initializer = _ControlledFakeInitializer();
        var callbackCount = 0;

        await tester.pumpWidget(
          _buildSplash(
            initializer: initializer,
            ttsService: TtsService(client: fakeClient),
            onGreetingCompleted: (result) {
              callbackCount++;
              expect(result.isSuccess, isTrue);
              throw StateError('Observer failure');
            },
          ),
        );
        initializer.completeSuccess();
        await tester.pump();
        fakeClient.completePlayback();
        await tester.pumpAndSettle();

        expect(callbackCount, 1);
        expect(fakeClient.spokenTexts, [AppStrings.splashGreeting]);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'retry berulang hanya menjalankan satu alur greeting dan navigasi',
      (WidgetTester tester) async {
        final fakeClient = _FakeTtsClient();
        final initializer = _ControlledFakeInitializer();
        final observer = _TrackingNavigatorObserver();

        await tester.pumpWidget(
          _buildSplash(
            initializer: initializer,
            ttsService: TtsService(client: fakeClient),
            navigatorObservers: [observer],
          ),
        );
        initializer.completeFailure('Initialization failed');
        await tester.pump();
        expect(find.text('Coba Lagi'), findsOneWidget);

        initializer.reset();
        final retry = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        retry.onPressed!();
        retry.onPressed!();
        expect(initializer.initializeCallCount, 2);

        await tester.pump();
        initializer.completeSuccess();
        await tester.pump();
        expect(fakeClient.speakCallCount, 1);
        fakeClient.completePlayback();
        await tester.pumpAndSettle();

        expect(observer.replaceCount, 1);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(fakeClient.spokenTexts, [AppStrings.splashGreeting]);
      },
    );

    testWidgets('dispose saat TTS aktif menghentikan audio tanpa navigasi', (
      WidgetTester tester,
    ) async {
      final fakeClient = _FakeTtsClient();
      final initializer = _ControlledFakeInitializer();

      await tester.pumpWidget(
        _buildSplash(
          initializer: initializer,
          ttsService: TtsService(client: fakeClient),
          navigateToHome: false,
        ),
      );
      initializer.completeSuccess();
      await tester.pump();
      expect(fakeClient.speakCallCount, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(fakeClient.stopCallCount, 1);
      expect(find.byType(HomeScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

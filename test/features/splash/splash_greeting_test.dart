import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/features/home/screens/home_screen.dart';
import 'package:daily_brief/features/splash/screens/splash_screen.dart';
import 'package:daily_brief/services/app_initializer.dart';
import 'package:daily_brief/services/tts_service.dart';

/// Fake TtsClient untuk menyimulasikan siklus hidup Text-to-Speech secara deterministik
/// pada widget test tanpa memanggil channel audio perangkat fisik.
class _FakeTtsClient implements TtsClient {
  String? lastSpokenText;
  int speakInvocationReturnCode = 1;
  bool shouldThrowOnSpeak = false;
  bool stopped = false;

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
    if (shouldThrowOnSpeak) {
      throw Exception('Simulasi kegagalan native speak');
    }
    lastSpokenText = text;
    startHandler?.call();
    return speakInvocationReturnCode;
  }

  @override
  Future<dynamic> stop() async {
    stopped = true;
    cancelHandler?.call();
    return 1;
  }

  @override
  void setStartHandler(VoidCallback callback) {
    startHandler = callback;
  }

  @override
  void setCompletionHandler(VoidCallback callback) {
    completionHandler = callback;
  }

  @override
  void setErrorHandler(void Function(dynamic message) callback) {
    errorHandler = callback;
  }

  @override
  void setCancelHandler(VoidCallback callback) {
    cancelHandler = callback;
  }

  void triggerCompletion() {
    completionHandler?.call();
  }

  void triggerError(dynamic message) {
    errorHandler?.call(message);
  }
}

/// Fake AppInitializer yang dapat dikontrol.
class _ControlledFakeInitializer extends AppInitializer {
  final Completer<InitializationResult> _completer = Completer<InitializationResult>();

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

  @override
  Future<InitializationResult> initialize() {
    return _completer.future;
  }
}

void main() {
  group('TASK-21 — Sapaan Kunjungan Pertama pada Splash Screen', () {
    late _FakeTtsClient fakeClient;
    late TtsService ttsService;

    setUp(() {
      fakeClient = _FakeTtsClient();
      ttsService = TtsService(client: fakeClient);
    });

    testWidgets(
        '1. Membacakan panduan awal yang benar dan belum pindah ke Home Screen selama sapaan berlangsung',
        (WidgetTester tester) async {
      final initializer = _ControlledFakeInitializer();

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
          ),
        ),
      );

      // Selesaikan inisialisasi layanan dasar
      initializer.completeSuccess();
      await tester.pump();

      // Verifikasi bahwa sapaan pertama dibacakan dengan teks panduan awal yang benar
      expect(fakeClient.lastSpokenText, AppStrings.firstVisitGreeting);
      expect(
        fakeClient.lastSpokenText,
        'Selamat datang di DailyBrief. Saya siap membantu memberikan informasi harian. Sentuh area utama layar untuk mulai bertanya.',
      );

      // Selama sapaan belum selesai, HomeScreen belum ditampilkan
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(ttsService.isSpeaking, isTrue);

      // Simulasikan penyelesaian pemutaran suara secara nyata dari platform
      fakeClient.triggerCompletion();
      await tester.pumpAndSettle();

      // Setelah sapaan selesai diputar, navigasi ke HomeScreen berhasil
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets(
        '2. Langsung melanjutkan ke Home Screen jika terjadi kegagalan TTS (error callback)',
        (WidgetTester tester) async {
      final initializer = _ControlledFakeInitializer();
      TtsPlaybackResult? completedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
            onGreetingCompleted: (result) {
              completedResult = result;
            },
          ),
        ),
      );

      initializer.completeSuccess();
      await tester.pump();

      // Pemutaran sapaan mulai dipanggil
      expect(fakeClient.lastSpokenText, AppStrings.firstVisitGreeting);

      // Simulasikan kegagalan engine TTS
      fakeClient.triggerError('Audio device error');
      await tester.pumpAndSettle();

      // Sistem tidak membuat pengguna terjebak di Splash Screen: langsung pindah ke HomeScreen
      expect(completedResult?.isFailure, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets(
        '3. Langsung melanjutkan ke Home Screen jika pemanggilan speak melempar exception',
        (WidgetTester tester) async {
      fakeClient.shouldThrowOnSpeak = true;
      final initializer = _ControlledFakeInitializer();
      TtsPlaybackResult? completedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
            onGreetingCompleted: (result) {
              completedResult = result;
            },
          ),
        ),
      );

      initializer.completeSuccess();
      await tester.pumpAndSettle();

      // Gagal saat speak langsung lanjut ke HomeScreen
      expect(completedResult?.isFailure, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets(
        '4. Sapaan tidak diputar jika inisialisasi layanan dasar gagal',
        (WidgetTester tester) async {
      final initializer = _ControlledFakeInitializer();

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
          ),
        ),
      );

      initializer.completeFailure('Koneksi sistem gagal');
      await tester.pump();

      // Sapaan TTS tidak boleh dipanggil jika inisialisasi gagal
      expect(fakeClient.lastSpokenText, isNull);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Koneksi sistem gagal'), findsOneWidget);
    });

    testWidgets(
        '5. Menghentikan pemutaran suara jika SplashScreen di-dispose saat berbicara',
        (WidgetTester tester) async {
      final initializer = _ControlledFakeInitializer();

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
            navigateToHome: false, // Jangan auto-navigate untuk mengontrol siklus hidup widget
          ),
        ),
      );

      initializer.completeSuccess();
      await tester.pump();

      expect(ttsService.isSpeaking, isTrue);

      // Ganti widget dengan widget kosong (memicu dispose pada SplashScreen)
      await tester.pumpWidget(const SizedBox.shrink());

      // Verifikasi audio dihentikan agar tidak menggantung
      expect(fakeClient.stopped, isTrue);
    });
  });
}

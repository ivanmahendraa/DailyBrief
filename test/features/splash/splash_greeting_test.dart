import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/features/home/screens/home_screen.dart';
import 'package:daily_brief/features/splash/screens/splash_screen.dart';
import 'package:daily_brief/services/app_initializer.dart';
import 'package:daily_brief/services/preference_service.dart';
import 'package:daily_brief/services/tts_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake TtsClient
// ─────────────────────────────────────────────────────────────────────────────

/// Fake TtsClient untuk menyimulasikan siklus hidup Text-to-Speech secara deterministik
/// pada widget test tanpa memanggil channel audio perangkat fisik.
class _FakeTtsClient implements TtsClient {
  String? lastSpokenText;
  final List<String> spokenTexts = [];
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
    spokenTexts.add(text);
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

// ─────────────────────────────────────────────────────────────────────────────
// Fake AppInitializer
// ─────────────────────────────────────────────────────────────────────────────

/// Fake AppInitializer yang dapat dikontrol.
class _ControlledFakeInitializer extends AppInitializer {
  final Completer<InitializationResult> _completer =
      Completer<InitializationResult>();

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

// ─────────────────────────────────────────────────────────────────────────────
// Fake PreferenceService
// ─────────────────────────────────────────────────────────────────────────────

/// Fake PreferenceService yang dapat dikonfigurasi untuk mengembalikan
/// status kunjungan pertama atau kunjungan berulang secara deterministik.
class _FakePreferenceService extends PreferenceService {
  bool firstVisitValue;
  bool markCompleted = false;

  _FakePreferenceService({this.firstVisitValue = true}) : super();

  @override
  Future<bool> isFirstVisit() async => firstVisitValue;

  @override
  Future<bool> markFirstVisitCompleted() async {
    markCompleted = true;
    firstVisitValue = false;
    return true;
  }

  @override
  Future<bool> resetFirstVisit() async {
    firstVisitValue = true;
    markCompleted = false;
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test Suite
// ─────────────────────────────────────────────────────────────────────────────

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
      // Kunjungan pertama: isFirstVisit == true
      final prefService = _FakePreferenceService(firstVisitValue: true);

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
            preferenceService: prefService,
          ),
        ),
      );

      // Selesaikan inisialisasi layanan dasar
      initializer.completeSuccess();
      await tester.pump();

      // Verifikasi bahwa sapaan pertama dibacakan dengan teks kunjungan pertama
      expect(fakeClient.lastSpokenText, AppStrings.firstVisitGreeting);
      expect(
        fakeClient.lastSpokenText,
        'Selamat datang di DailyBrief.',
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

      // Verifikasi pesan kedua dibacakan setelah Home Screen terbuka
      expect(fakeClient.lastSpokenText, AppStrings.homeGreeting);
      expect(fakeClient.lastSpokenText, 'Temukan informasi dalam satu sentuhan.');
      expect(fakeClient.spokenTexts, [
        AppStrings.firstVisitGreeting,
        AppStrings.homeGreeting,
      ]);

      // Verifikasi status kunjungan pertama ditandai selesai
      expect(prefService.markCompleted, isTrue);

      // Verifikasi bahwa dispose() pada SplashScreen TIDAK memanggil stop() pada TTS kedua
      expect(fakeClient.stopped, isFalse);

      // Verifikasi pengamanan: jika HomeScreen benar-benar di-dispose (pengguna keluar),
      // audio TTS dihentikan
      await tester.pumpWidget(const SizedBox.shrink());
      expect(fakeClient.stopped, isTrue);
    });

    testWidgets(
        '2. Membacakan sapaan kunjungan berulang jika bukan kunjungan pertama',
        (WidgetTester tester) async {
      final initializer = _ControlledFakeInitializer();
      // Kunjungan berulang: isFirstVisit == false
      final prefService = _FakePreferenceService(firstVisitValue: false);

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
            preferenceService: prefService,
          ),
        ),
      );

      initializer.completeSuccess();
      await tester.pump();

      // Verifikasi sapaan kunjungan berulang digunakan
      expect(fakeClient.lastSpokenText, AppStrings.returningVisitGreeting);
      expect(fakeClient.lastSpokenText, 'Selamat datang kembali di DailyBrief.');

      // markCompleted tidak dipanggil untuk kunjungan berulang
      expect(prefService.markCompleted, isFalse);

      fakeClient.triggerCompletion();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
        '3. Langsung melanjutkan ke Home Screen jika terjadi kegagalan TTS (error callback)',
        (WidgetTester tester) async {
      final initializer = _ControlledFakeInitializer();
      final prefService = _FakePreferenceService(firstVisitValue: true);
      TtsPlaybackResult? completedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
            preferenceService: prefService,
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
        '4. Langsung melanjutkan ke Home Screen jika pemanggilan speak melempar exception',
        (WidgetTester tester) async {
      fakeClient.shouldThrowOnSpeak = true;
      final initializer = _ControlledFakeInitializer();
      final prefService = _FakePreferenceService(firstVisitValue: true);
      TtsPlaybackResult? completedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
            preferenceService: prefService,
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
        '5. Sapaan tidak diputar jika inisialisasi layanan dasar gagal',
        (WidgetTester tester) async {
      final initializer = _ControlledFakeInitializer();
      final prefService = _FakePreferenceService(firstVisitValue: true);

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
            preferenceService: prefService,
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
        '6. Menghentikan pemutaran suara jika SplashScreen di-dispose saat berbicara',
        (WidgetTester tester) async {
      final initializer = _ControlledFakeInitializer();
      final prefService = _FakePreferenceService(firstVisitValue: true);

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: initializer,
            ttsService: ttsService,
            preferenceService: prefService,
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

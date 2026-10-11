import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/app.dart';
import 'package:daily_brief/features/home/screens/home_screen.dart';
import 'package:daily_brief/features/splash/screens/splash_screen.dart';
import 'package:daily_brief/services/app_initializer.dart';
import 'package:daily_brief/services/tts_service.dart';

/// Fake implementation of [TtsClient] yang segera menyelesaikan pemutaran suara
/// untuk mendukung pengujian kontrol navigasi widget secara deterministik.
class _ImmediateFakeTtsClient implements TtsClient {
  VoidCallback? _completionHandler;

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

/// Fake initializer yang perilakunya dapat dikontrol secara deterministik
/// untuk menguji kondisi loading, sukses, dan gagal tanpa bergantung pada waktu nyata.
class _ControlledFakeInitializer extends AppInitializer {
  Completer<InitializationResult> _completer = Completer<InitializationResult>();

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

  @override
  Future<InitializationResult> initialize() {
    return _completer.future;
  }
}

void main() {
  group('TASK-10: Alur Splash Screen dan Navigasi Terkontrol', () {
    late TtsService immediateTtsService;

    setUp(() {
      immediateTtsService = TtsService(client: _ImmediateFakeTtsClient());
    });

    testWidgets('1. Splash Screen ditampilkan pada awal peluncuran aplikasi',
        (WidgetTester tester) async {
      await tester.pumpWidget(DailyBriefApp(ttsService: immediateTtsService));

      // Verifikasi identitas dan komponen Splash Screen pada peluncuran
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('DailyBrief'), findsOneWidget);
      expect(find.text('Temukan Informasi dalam Satu Sentuhan'), findsOneWidget);

      // Selesaikan frame dan navigasi
      await tester.pumpAndSettle();
    });

    testWidgets('2. Indikator loading muncul ketika inisialisasi masih berlangsung',
        (WidgetTester tester) async {
      final controlledInitializer = _ControlledFakeInitializer();

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: controlledInitializer,
            ttsService: immediateTtsService,
          ),
        ),
      );

      // Frame awal selesai digambar dan inisialisasi masih pending
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Menyiapkan informasi...'), findsOneWidget);
      expect(find.text('DailyBrief'), findsOneWidget);
      expect(find.text('Temukan Informasi dalam Satu Sentuhan'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // Lengkapi proses agar tidak ada future menggantung
      controlledInitializer.completeSuccess();
      await tester.pumpAndSettle();
    });

    testWidgets('3. Inisialisasi berhasil menyebabkan navigasi ke Home Screen',
        (WidgetTester tester) async {
      final controlledInitializer = _ControlledFakeInitializer();

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: controlledInitializer,
            ttsService: immediateTtsService,
          ),
        ),
      );

      // Status awal: Splash Screen aktif
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // Selesaikan inisialisasi dengan sukses
      controlledInitializer.completeSuccess();
      await tester.pumpAndSettle();

      // Status akhir: Berpindah ke HomeScreen dan SplashScreen digantikan
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Halaman Utama DailyBrief'), findsOneWidget);
    });

    testWidgets('4. Inisialisasi gagal tidak menyebabkan navigasi dan menampilkan pesan error',
        (WidgetTester tester) async {
      final controlledInitializer = _ControlledFakeInitializer();

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: controlledInitializer,
            ttsService: immediateTtsService,
          ),
        ),
      );

      // Selesaikan inisialisasi dengan kegagalan
      controlledInitializer.completeFailure(
        'Gagal menyiapkan aplikasi. Sentuh coba lagi untuk mengulang.',
      );
      await tester.pump();

      // Verifikasi pesan kesalahan dan tombol Coba Lagi
      expect(find.text('Gagal menyiapkan aplikasi. Sentuh coba lagi untuk mengulang.'),
          findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Verifikasi tidak berpindah ke HomeScreen
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(SplashScreen), findsOneWidget);
    });

    testWidgets('5. Tombol Coba Lagi mengulang proses dan menavigasi saat percobaan berhasil',
        (WidgetTester tester) async {
      final controlledInitializer = _ControlledFakeInitializer();

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            initializer: controlledInitializer,
            ttsService: immediateTtsService,
          ),
        ),
      );

      // Awalnya gagal
      controlledInitializer.completeFailure(
        'Gagal menyiapkan aplikasi. Sentuh coba lagi untuk mengulang.',
      );
      await tester.pump();
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Reset untuk percobaan ulang berikutnya
      controlledInitializer.reset();

      // Tekan tombol Coba Lagi
      await tester.tap(find.text('Coba Lagi'));
      await tester.pump();

      // Verifikasi indikator loading kembali muncul
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // Percobaan ulang berhasil
      controlledInitializer.completeSuccess();
      await tester.pumpAndSettle();

      // Verifikasi navigasi ke HomeScreen berhasil
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    test('AppInitializer unit test returns success on standard call', () async {
      const initializer = AppInitializer();
      final result = await initializer.initialize();

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.errorMessage, isNull);
    });
  });
}

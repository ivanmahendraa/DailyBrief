import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/services/tts_service.dart';

/// Fake implementation of [TtsClient] yang memungkinkan simulasi event native TTS
/// secara deterministik dan terisolasi tanpa membutuhkan hardware audio fisik.
class _FakeTtsClient implements TtsClient {
  String? configuredLanguage;
  double? configuredRate;
  double? configuredVolume;
  double? configuredPitch;
  bool? configuredAwaitCompletion;
  String? lastSpokenText;
  int speakInvocationReturnCode = 1;

  bool shouldThrowOnInitialize = false;
  bool shouldThrowOnSpeak = false;

  VoidCallback? startHandler;
  VoidCallback? completionHandler;
  void Function(dynamic message)? errorHandler;
  VoidCallback? cancelHandler;

  bool Function(String language)? languageAvailabilityChecker;

  @override
  Future<dynamic> isLanguageAvailable(String language) async {
    if (languageAvailabilityChecker != null) {
      return languageAvailabilityChecker!(language);
    }
    return true;
  }

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {
    configuredAwaitCompletion = awaitCompletion;
    return 1;
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    if (shouldThrowOnInitialize) {
      throw Exception('Gagal memuat modul bahasa native');
    }
    configuredLanguage = language;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    configuredPitch = pitch;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    configuredRate = rate;
    return 1;
  }

  @override
  Future<dynamic> setVolume(double volume) async {
    configuredVolume = volume;
    return 1;
  }

  @override
  Future<dynamic> speak(String text) async {
    if (shouldThrowOnSpeak) {
      throw Exception('Native TTS engine error');
    }
    lastSpokenText = text;
    startHandler?.call();
    return speakInvocationReturnCode;
  }

  @override
  Future<dynamic> stop() async {
    cancelHandler?.call();
    return 1;
  }

  @override
  void setCancelHandler(VoidCallback callback) {
    cancelHandler = callback;
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
  void setStartHandler(VoidCallback callback) {
    startHandler = callback;
  }

  void triggerCompletion() {
    completionHandler?.call();
  }

  void triggerError(dynamic message) {
    errorHandler?.call(message);
  }
}

void main() {
  group('TASK-19: TtsService Unit Tests', () {
    late _FakeTtsClient fakeClient;
    late TtsService service;

    setUp(() {
      fakeClient = _FakeTtsClient();
      service = TtsService(client: fakeClient);
    });

    test('1. Inisialisasi awal menyetel bahasa id-ID dan handler dengan sukses', () async {
      expect(service.state, equals(TtsState.uninitialized));

      final success = await service.initialize(language: 'id-ID');

      expect(success, isTrue);
      expect(service.state, equals(TtsState.ready));
      expect(fakeClient.configuredLanguage, equals('id-ID'));
      expect(fakeClient.configuredAwaitCompletion, isTrue);
      expect(service.lastErrorMessage, isNull);
    });

    test('2. Inisialisasi menangani kegagalan dengan aman tanpa crash', () async {
      fakeClient.shouldThrowOnInitialize = true;

      final success = await service.initialize();

      expect(success, isFalse);
      expect(service.state, equals(TtsState.error));
      expect(service.lastErrorMessage, contains('Gagal menginisialisasi'));
    });

    test('3. Pemutaran teks kosong langsung mengembalikan failure tanpa memanggil engine', () async {
      await service.initialize();

      final result = await service.speak('   ');

      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('tidak boleh kosong'));
      expect(fakeClient.lastSpokenText, isNull);
    });

    test('4. Pemutaran teks menunggu completion callback native secara deterministik', () async {
      await service.initialize();

      bool isCompleted = false;
      final speakFuture = service.speak('Selamat datang di DailyBrief').then((res) {
        isCompleted = true;
        return res;
      });

      // Berikan microtask agar invocation `speak` berjalan
      await Future<void>.delayed(Duration.zero);

      expect(service.state, equals(TtsState.speaking));
      expect(service.isSpeaking, isTrue);
      expect(isCompleted, isFalse); // Belum selesai karena menunggu completion handler

      // Simulasikan sinyal selesai dari platform native
      fakeClient.triggerCompletion();

      final result = await speakFuture;

      expect(isCompleted, isTrue);
      expect(result.isSuccess, isTrue);
      expect(service.state, equals(TtsState.ready));
      expect(service.isSpeaking, isFalse);
    });

    test('5. Pemutaran teks menangani error native callback dengan aman', () async {
      await service.initialize();

      final speakFuture = service.speak('Halo pengguna DailyBrief');
      await Future<void>.delayed(Duration.zero);

      // Simulasikan pesan kesalahan dari platform native
      fakeClient.triggerError('Audio track init failed');

      final result = await speakFuture;

      expect(result.isFailure, isTrue);
      expect(result.errorMessage, equals('Audio track init failed'));
      expect(service.state, equals(TtsState.error));
      expect(service.lastErrorMessage, equals('Audio track init failed'));
    });

    test('6. Pemutaran teks menangani exception langsung saat pemanggilan speak', () async {
      await service.initialize();
      fakeClient.shouldThrowOnSpeak = true;

      final result = await service.speak('Tes pemanggilan gagal');

      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('Terjadi kesalahan saat memutar suara'));
      expect(service.state, equals(TtsState.error));
    });

    test('7. Memanggil stop() membatalkan pemutaran yang sedang berlangsung', () async {
      await service.initialize();

      final speakFuture = service.speak('Kalimat yang akan dihentikan di tengah jalan');
      await Future<void>.delayed(Duration.zero);

      expect(service.isSpeaking, isTrue);

      await service.stop();

      final result = await speakFuture;

      expect(result.isCancelled, isTrue);
      expect(service.state, equals(TtsState.stopped));
    });

    test('8. Konfigurasi laju, volume, dan nada suara memanggil client dengan benar', () async {
      await service.initialize();

      final rateSuccess = await service.setSpeechRate(0.5);
      final volumeSuccess = await service.setVolume(1.0);
      final pitchSuccess = await service.setPitch(1.0);

      expect(rateSuccess, isTrue);
      expect(volumeSuccess, isTrue);
      expect(pitchSuccess, isTrue);
      expect(fakeClient.configuredRate, equals(0.5));
      expect(fakeClient.configuredVolume, equals(1.0));
      expect(fakeClient.configuredPitch, equals(1.0));
    });

    test('9. Inisialisasi default otomatis menerapkan bahasa id-ID, laju 0.5, dan volume 1.0 (TASK-20)', () async {
      final success = await service.initialize();

      expect(success, isTrue);
      expect(service.currentLanguage, equals('id-ID'));
      expect(service.currentSpeechRate, equals(0.5));
      expect(service.currentVolume, equals(1.0));
      expect(service.currentPitch, equals(1.0));
      expect(fakeClient.configuredLanguage, equals('id-ID'));
      expect(fakeClient.configuredRate, equals(0.5));
      expect(fakeClient.configuredVolume, equals(1.0));
    });

    test('10. Inisialisasi beralih ke kode alternatif "id" jika "id-ID" tidak tersedia (TASK-20)', () async {
      fakeClient.languageAvailabilityChecker = (lang) {
        if (lang == 'id-ID') return false;
        if (lang == 'id') return true;
        return false;
      };

      final success = await service.initialize();

      expect(success, isTrue);
      expect(service.currentLanguage, equals('id'));
      expect(fakeClient.configuredLanguage, equals('id'));
      expect(service.currentSpeechRate, equals(0.5));
      expect(service.currentVolume, equals(1.0));
    });

    test('11. Inisialisasi tetap melakukan fallback aman jika bahasa Indonesia tidak terdeteksi (TASK-20)', () async {
      fakeClient.languageAvailabilityChecker = (_) => false;

      final success = await service.initialize();

      expect(success, isTrue);
      expect(service.currentLanguage, equals('id-ID'));
      expect(fakeClient.configuredLanguage, equals('id-ID'));
    });
  });
}

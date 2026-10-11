import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Status operasional Text-to-Speech service.
enum TtsState {
  uninitialized,
  ready,
  speaking,
  stopped,
  error,
}

/// Status hasil dari proses pemutaran suara.
enum TtsPlaybackStatus {
  success,
  failure,
  cancelled,
}

/// Representasi hasil pemutaran suara yang memuat status dan pesan error bila ada.
class TtsPlaybackResult {
  final TtsPlaybackStatus status;
  final String? errorMessage;

  const TtsPlaybackResult._({
    required this.status,
    this.errorMessage,
  });

  factory TtsPlaybackResult.success() =>
      const TtsPlaybackResult._(status: TtsPlaybackStatus.success);

  factory TtsPlaybackResult.failure(String message) => TtsPlaybackResult._(
        status: TtsPlaybackStatus.failure,
        errorMessage: message,
      );

  factory TtsPlaybackResult.cancelled() =>
      const TtsPlaybackResult._(status: TtsPlaybackStatus.cancelled);

  bool get isSuccess => status == TtsPlaybackStatus.success;
  bool get isFailure => status == TtsPlaybackStatus.failure;
  bool get isCancelled => status == TtsPlaybackStatus.cancelled;
}

/// Kontrak abstraksi antarmuka FlutterTts untuk mendukung dependency injection
/// dan pengujian unit tanpa bergantung pada audio hardware perangkat fisik.
abstract class TtsClient {
  Future<dynamic> isLanguageAvailable(String language);
  Future<dynamic> setLanguage(String language);
  Future<dynamic> setSpeechRate(double rate);
  Future<dynamic> setVolume(double volume);
  Future<dynamic> setPitch(double pitch);
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion);
  Future<dynamic> speak(String text);
  Future<dynamic> stop();
  void setStartHandler(VoidCallback callback);
  void setCompletionHandler(VoidCallback callback);
  void setErrorHandler(void Function(dynamic message) callback);
  void setCancelHandler(VoidCallback callback);
}

/// Implementasi default [TtsClient] yang membungkus instance nyata [FlutterTts].
class DefaultFlutterTtsClient implements TtsClient {
  final FlutterTts _flutterTts;

  DefaultFlutterTtsClient([FlutterTts? flutterTts])
      : _flutterTts = flutterTts ?? FlutterTts();

  @override
  Future<dynamic> isLanguageAvailable(String language) =>
      _flutterTts.isLanguageAvailable(language);

  @override
  Future<dynamic> setLanguage(String language) =>
      _flutterTts.setLanguage(language);

  @override
  Future<dynamic> setSpeechRate(double rate) =>
      _flutterTts.setSpeechRate(rate);

  @override
  Future<dynamic> setVolume(double volume) => _flutterTts.setVolume(volume);

  @override
  Future<dynamic> setPitch(double pitch) => _flutterTts.setPitch(pitch);

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) =>
      _flutterTts.awaitSpeakCompletion(awaitCompletion);

  @override
  Future<dynamic> speak(String text) => _flutterTts.speak(text);

  @override
  Future<dynamic> stop() => _flutterTts.stop();

  @override
  void setStartHandler(VoidCallback callback) =>
      _flutterTts.setStartHandler(callback);

  @override
  void setCompletionHandler(VoidCallback callback) =>
      _flutterTts.setCompletionHandler(callback);

  @override
  void setErrorHandler(void Function(dynamic message) callback) =>
      _flutterTts.setErrorHandler(callback);

  @override
  void setCancelHandler(VoidCallback callback) =>
      _flutterTts.setCancelHandler(callback);
}

/// Service untuk mengelola Text-to-Speech (TTS) pada aplikasi DailyBrief.
///
/// Bertanggung jawab atas:
/// - Inisialisasi engine TTS dan pendaftaran event handler asli.
/// - Pengaturan bahasa default (Bahasa Indonesia `id-ID`) dengan deteksi ketersediaan pada perangkat.
/// - Pemilihan laju bicara dan volume suara default yang jelas dan mudah dipahami.
/// - Pemutaran teks dengan deteksi penyelesaian suara yang sesungguhnya
///   berbasis event callback (tanpa simulasi `Future.delayed`).
/// - Penanganan kegagalan atau error tanpa menyebabkan crash pada aplikasi.
class TtsService {
  /// Bahasa default aplikasi DailyBrief (Bahasa Indonesia).
  static const String defaultLanguage = 'id-ID';

  /// Laju bicara default yang mudah dipahami bagi pengguna (termasuk tunanetra).
  static const double defaultSpeechRate = 0.5;

  /// Volume suara default (maksimal dan jelas).
  static const double defaultVolume = 1.0;

  /// Nada bicara default (natural dan jelas).
  static const double defaultPitch = 1.0;

  final TtsClient _client;

  TtsState _state = TtsState.uninitialized;
  String? _lastErrorMessage;
  Completer<TtsPlaybackResult>? _speakCompleter;

  String _currentLanguage = defaultLanguage;
  double _currentSpeechRate = defaultSpeechRate;
  double _currentVolume = defaultVolume;
  double _currentPitch = defaultPitch;

  TtsService({TtsClient? client})
      : _client = client ?? DefaultFlutterTtsClient();

  /// Status operasional TTS saat ini.
  TtsState get state => _state;

  /// Pesan kesalahan terakhir jika terjadi kegagalan.
  String? get lastErrorMessage => _lastErrorMessage;

  /// Menandakan apakah TTS saat ini sedang memutar suara.
  bool get isSpeaking => _state == TtsState.speaking;

  /// Menandakan apakah TTS siap menerima instruksi pemutaran teks.
  bool get isReady =>
      _state == TtsState.ready ||
      _state == TtsState.speaking ||
      _state == TtsState.stopped;

  /// Bahasa aktif saat ini.
  String get currentLanguage => _currentLanguage;

  /// Laju bicara aktif saat ini.
  double get currentSpeechRate => _currentSpeechRate;

  /// Volume aktif saat ini.
  double get currentVolume => _currentVolume;

  /// Nada bicara aktif saat ini.
  double get currentPitch => _currentPitch;

  /// Memeriksa apakah suatu bahasa tersedia pada perangkat.
  Future<bool> isLanguageAvailable(String language) async {
    try {
      final result = await _client.isLanguageAvailable(language);
      if (result is bool) return result;
      if (result is int) return result == 1;
      return result != null;
    } catch (error) {
      debugPrint('TtsService.isLanguageAvailable error: $error');
      return false;
    }
  }

  /// Menginisialisasi engine TTS dengan bahasa dan handler native.
  ///
  /// Secara otomatis mengatur bahasa Indonesia (`id-ID`) apabila tersedia pada perangkat,
  /// serta menerapkan laju bicara (`0.5`) dan volume (`1.0`) default yang mudah dipahami.
  ///
  /// Mengembalikan `true` jika inisialisasi berhasil, atau `false` jika terjadi error.
  Future<bool> initialize({
    String language = defaultLanguage,
    double speechRate = defaultSpeechRate,
    double volume = defaultVolume,
    double pitch = defaultPitch,
  }) async {
    try {
      _lastErrorMessage = null;

      _client.setStartHandler(() {
        _state = TtsState.speaking;
      });

      _client.setCompletionHandler(() {
        _onPlaybackCompleted();
      });

      _client.setErrorHandler((message) {
        _onPlaybackError(message?.toString() ?? 'Terjadi kesalahan pada layanan TTS');
      });

      _client.setCancelHandler(() {
        _onPlaybackCancelled();
      });

      // Periksa ketersediaan bahasa Indonesia pada perangkat
      final isAvailable = await isLanguageAvailable(language);
      if (isAvailable) {
        await _client.setLanguage(language);
        _currentLanguage = language;
      } else {
        // Coba kode bahasa alternatif 'id' jika 'id-ID' tidak langsung dikenali
        final isShortAvailable = await isLanguageAvailable('id');
        if (isShortAvailable) {
          await _client.setLanguage('id');
          _currentLanguage = 'id';
        } else {
          // Tetap coba setel bahasa yang diminta sebagai fallback
          await _client.setLanguage(language);
          _currentLanguage = language;
        }
      }

      // Atur laju bicara dan volume yang mudah dipahami
      await _client.setSpeechRate(speechRate);
      _currentSpeechRate = speechRate;

      await _client.setVolume(volume);
      _currentVolume = volume;

      await _client.setPitch(pitch);
      _currentPitch = pitch;

      await _client.awaitSpeakCompletion(true);

      _state = TtsState.ready;
      return true;
    } catch (error, stackTrace) {
      debugPrint('TtsService.initialize error: $error\n$stackTrace');
      _lastErrorMessage = 'Gagal menginisialisasi Text-to-Speech: $error';
      _state = TtsState.error;
      return false;
    }
  }

  /// Mengatur bahasa keluaran TTS.
  Future<bool> setLanguage(String language) async {
    try {
      await _client.setLanguage(language);
      _currentLanguage = language;
      return true;
    } catch (error) {
      debugPrint('TtsService.setLanguage error: $error');
      _lastErrorMessage = 'Gagal mengatur bahasa TTS: $error';
      return false;
    }
  }

  /// Mengatur kecepatan bicara (speech rate).
  Future<bool> setSpeechRate(double rate) async {
    try {
      await _client.setSpeechRate(rate);
      _currentSpeechRate = rate;
      return true;
    } catch (error) {
      debugPrint('TtsService.setSpeechRate error: $error');
      _lastErrorMessage = 'Gagal mengatur kecepatan bicara TTS: $error';
      return false;
    }
  }

  /// Mengatur volume keluaran suara (0.0 sampai 1.0).
  Future<bool> setVolume(double volume) async {
    try {
      await _client.setVolume(volume);
      _currentVolume = volume;
      return true;
    } catch (error) {
      debugPrint('TtsService.setVolume error: $error');
      _lastErrorMessage = 'Gagal mengatur volume suara TTS: $error';
      return false;
    }
  }

  /// Mengatur nada suara (pitch).
  Future<bool> setPitch(double pitch) async {
    try {
      await _client.setPitch(pitch);
      _currentPitch = pitch;
      return true;
    } catch (error) {
      debugPrint('TtsService.setPitch error: $error');
      _lastErrorMessage = 'Gagal mengatur nada suara TTS: $error';
      return false;
    }
  }

  /// Memutar [text] dan menunggu hingga pemutaran suara benar-benar selesai
  /// berdasarkan event completion native dari platform (tanpa penundaan tiruan `Future.delayed`).
  ///
  /// Mengembalikan [TtsPlaybackResult] yang mengindikasikan status sukses, dibatalkan,
  /// atau gagal beserta rincian pesannya.
  Future<TtsPlaybackResult> speak(String text) async {
    if (text.trim().isEmpty) {
      return TtsPlaybackResult.failure('Teks yang akan dibacakan tidak boleh kosong.');
    }

    if (_state == TtsState.uninitialized) {
      final initSuccess = await initialize();
      if (!initSuccess) {
        return TtsPlaybackResult.failure(
          _lastErrorMessage ?? 'Layanan Text-to-Speech belum siap.',
        );
      }
    }

    // Jika sedang berbicara, hentikan sesi sebelumnya terlebih dahulu
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      await stop();
    }

    _lastErrorMessage = null;
    final completer = Completer<TtsPlaybackResult>();
    _speakCompleter = completer;

    try {
      _state = TtsState.speaking;
      final speakInvocationResult = await _client.speak(text);

      // Beberapa platform mengembalikan int status (misal 1 untuk sukses mulai di Android/iOS)
      if (speakInvocationResult == 0) {
        _state = TtsState.error;
        _lastErrorMessage = 'Engine TTS menolak permintaan pemutaran suara.';
        _resolvePendingCompleter(TtsPlaybackResult.failure(_lastErrorMessage!));
        return await completer.future;
      }

      return await completer.future;
    } catch (error, stackTrace) {
      debugPrint('TtsService.speak error: $error\n$stackTrace');
      _state = TtsState.error;
      _lastErrorMessage = 'Terjadi kesalahan saat memutar suara: $error';
      final failureResult = TtsPlaybackResult.failure(_lastErrorMessage!);
      _resolvePendingCompleter(failureResult);
      return failureResult;
    }
  }

  /// Menghentikan pemutaran suara yang sedang berlangsung.
  Future<void> stop() async {
    try {
      await _client.stop();
    } catch (error) {
      debugPrint('TtsService.stop error: $error');
    } finally {
      _state = TtsState.stopped;
      _resolvePendingCompleter(TtsPlaybackResult.cancelled());
    }
  }

  void _onPlaybackCompleted() {
    _state = TtsState.ready;
    _resolvePendingCompleter(TtsPlaybackResult.success());
  }

  void _onPlaybackError(String message) {
    debugPrint('TtsService native playback error: $message');
    _state = TtsState.error;
    _lastErrorMessage = message;
    _resolvePendingCompleter(TtsPlaybackResult.failure(message));
  }

  void _onPlaybackCancelled() {
    _state = TtsState.stopped;
    _resolvePendingCompleter(TtsPlaybackResult.cancelled());
  }

  void _resolvePendingCompleter(TtsPlaybackResult result) {
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete(result);
    }
    _speakCompleter = null;
  }
}

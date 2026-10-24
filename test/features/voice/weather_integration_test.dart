import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/features/voice/voice_controller.dart';
import 'package:daily_brief/features/voice/weather_response_generator.dart';
import 'package:daily_brief/services/date_time_service.dart';
import 'package:daily_brief/services/location_service.dart';
import 'package:daily_brief/services/speech_to_text_service.dart';
import 'package:daily_brief/services/tts_service.dart';
import 'package:daily_brief/services/weather_service.dart';

Position _createPosition({
  double latitude = 1.1301,
  double longitude = 104.0529,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 10, 24, 12, 0),
    accuracy: 5.0,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

class _StubTtsClient implements TtsClient {
  const _StubTtsClient();

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> isLanguageAvailable(String language) async => 1;

  @override
  void setCancelHandler(void Function() callback) {}

  @override
  void setCompletionHandler(void Function() callback) {}

  @override
  void setErrorHandler(void Function(dynamic message) callback) {}

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  void setStartHandler(void Function() callback) {}

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> speak(String text) async => 1;

  @override
  Future<dynamic> stop() async => 1;
}

class _IntegrationSpeechClient implements SpeechToTextClient {
  void Function(String status)? onStatus;
  void Function(String message, bool isPermanent)? onError;
  SpeechResultCallback? onResult;
  int listenCallCount = 0;
  int cancelCallCount = 0;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message, bool isPermanent) onError,
  }) async {
    this.onStatus = onStatus;
    this.onError = onError;
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
    this.onResult = onResult;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {
    cancelCallCount++;
  }

  void emitStatus(String status) => onStatus?.call(status);

  void emitResult(String words) => onResult?.call(
    SpeechRecognitionResult(recognizedWords: words, isFinal: true),
  );
}

class _IntegrationTtsService extends TtsService {
  final List<String> spokenTexts = [];
  Completer<TtsPlaybackResult>? pendingResponse;
  bool speaking = false;

  _IntegrationTtsService() : super(client: const _StubTtsClient());

  @override
  bool get isReady => true;

  @override
  bool get isSpeaking => speaking;

  String? get lastSpokenResponse {
    final nonConfirmation =
        spokenTexts.where((t) => t != AppStrings.voiceConfirmation).toList();
    return nonConfirmation.isNotEmpty ? nonConfirmation.last : null;
  }

  @override
  Future<bool> initialize({
    String language = TtsService.defaultLanguage,
    double speechRate = TtsService.defaultSpeechRate,
    double volume = TtsService.defaultVolume,
    double pitch = TtsService.defaultPitch,
  }) async => true;

  @override
  Future<TtsPlaybackResult> speak(String text) async {
    spokenTexts.add(text);
    speaking = true;

    if (text != AppStrings.voiceConfirmation && pendingResponse != null) {
      final res = await pendingResponse!.future;
      speaking = false;
      return res;
    }

    speaking = false;
    return TtsPlaybackResult.success();
  }

  @override
  Future<void> stop() async {
    speaking = false;
    if (pendingResponse != null && !pendingResponse!.isCompleted) {
      pendingResponse!.complete(TtsPlaybackResult.cancelled());
    }
  }
}

class _IntegrationLocationClient implements LocationClient {
  bool serviceEnabled = true;
  LocationPermission checkPermissionValue = LocationPermission.whileInUse;
  LocationPermission requestPermissionValue = LocationPermission.whileInUse;
  Position mockPosition = _createPosition();
  Duration? delay;
  bool throwOnGetPosition = false;
  bool throwTimeout = false;

  int checkCallCount = 0;
  int requestCallCount = 0;
  int getPositionCallCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    checkCallCount++;
    return checkPermissionValue;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestCallCount++;
    return requestPermissionValue;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    getPositionCallCount++;
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (throwTimeout) {
      throw TimeoutException('Coordinate fetch timed out');
    }
    if (throwOnGetPosition) {
      throw StateError('Position retrieval failed');
    }
    return mockPosition;
  }
}

class _IntegrationWeatherClient implements WeatherClient {
  WeatherResult resultToReturn = WeatherResult.success(
    const WeatherData(
      description: 'cerah berawan',
      temperature: 28.4,
      cityName: 'Batam',
      latitude: 1.1301,
      longitude: 104.0529,
    ),
  );

  int callCount = 0;
  double? lastLatitude;
  double? lastLongitude;
  Duration? delay;
  bool throwException = false;

  @override
  Future<WeatherResult> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    callCount++;
    lastLatitude = latitude;
    lastLongitude = longitude;
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (throwException) {
      throw StateError('Weather client crash');
    }
    return resultToReturn;
  }
}

class _WeatherTestFixture {
  final speechClient = _IntegrationSpeechClient();
  final ttsService = _IntegrationTtsService();
  final locationClient = _IntegrationLocationClient();
  final weatherClient = _IntegrationWeatherClient();

  late final LocationService locationService = LocationService(locationClient);
  late final WeatherService weatherService = WeatherService(weatherClient);
  late final SpeechToTextService speechService =
      SpeechToTextService(client: speechClient);
  late final DateTimeService dateTimeService =
      DateTimeService(now: () => DateTime(2026, 10, 24, 10, 0));

  late final VoiceController controller = VoiceController(
    dateTimeService: dateTimeService,
    speechToTextService: speechService,
    ttsService: ttsService,
    locationService: locationService,
    weatherService: weatherService,
    weatherResponseGenerator: const WeatherResponseGenerator(),
  );

  Future<void> startAndConfirmListening() async {
    final startFuture = controller.startListening();
    while (speechClient.listenCallCount == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    speechClient.emitStatus('listening');
    await startFuture;
  }

  Future<void> emitCommandAndComplete(String utterance) async {
    speechClient.emitResult(utterance);
    speechClient.emitStatus('done');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  void dispose() {
    controller.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK-55: Integrated Weather Feature Tests', () {
    late _WeatherTestFixture fixture;

    setUp(() {
      fixture = _WeatherTestFixture();
    });

    tearDown(() {
      fixture.dispose();
    });

    group('Alur Sukses (End-to-End Success Flow)', () {
      test(
        '1. Perintah suara cuaca -> CommandParser -> VoiceController -> LocationService -> WeatherService -> WeatherResponseGenerator -> TTS -> idle',
        () async {
          await fixture.startAndConfirmListening();
          expect(fixture.controller.state, VoiceInteractionState.listening);

          await fixture.emitCommandAndComplete('cuaca');

          expect(fixture.locationClient.getPositionCallCount, 1);
          expect(fixture.weatherClient.callCount, 1);
          expect(fixture.weatherClient.lastLatitude, 1.1301);
          expect(fixture.weatherClient.lastLongitude, 104.0529);

          expect(
            fixture.ttsService.lastSpokenResponse,
            'Cuaca di Batam saat ini cerah berawan dengan suhu 28 derajat Celsius.',
          );
          expect(fixture.controller.state, VoiceInteractionState.idle);
          expect(fixture.controller.hasActiveSession, isFalse);
        },
      );

      test(
        '2. Variasi ucapan perintah cuaca didukung oleh alur integrasi',
        () async {
          final variations = [
            'ramalan cuaca',
            'prakiraan cuaca',
            'bagaimana cuaca hari ini',
            'bagaimana prakiraan cuaca hari ini',
            'tolong cek cuaca',
          ];

          for (final utterance in variations) {
            await fixture.startAndConfirmListening();
            await fixture.emitCommandAndComplete(utterance);

            expect(
              fixture.ttsService.lastSpokenResponse,
              'Cuaca di Batam saat ini cerah berawan dengan suhu 28 derajat Celsius.',
            );
            expect(fixture.controller.state, VoiceInteractionState.idle);
          }

          expect(fixture.weatherClient.callCount, variations.length);
        },
      );

      test(
        '3. Verifikasi transisi state lengkap: listening -> processing -> speaking -> idle',
        () async {
          final ttsCompleter = Completer<TtsPlaybackResult>();
          fixture.ttsService.pendingResponse = ttsCompleter;

          final observedStates = <VoiceInteractionState>[];
          fixture.controller.addListener(() {
            observedStates.add(fixture.controller.state);
          });

          await fixture.startAndConfirmListening();
          expect(fixture.controller.state, VoiceInteractionState.listening);

          fixture.speechClient.emitResult('cuaca');
          fixture.speechClient.emitStatus('done');

          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          expect(fixture.controller.state, VoiceInteractionState.speaking);

          ttsCompleter.complete(TtsPlaybackResult.success());
          await Future<void>.delayed(Duration.zero);

          expect(fixture.controller.state, VoiceInteractionState.idle);
          expect(observedStates, containsAllInOrder([
            VoiceInteractionState.processing,
            VoiceInteractionState.speaking,
            VoiceInteractionState.idle,
          ]));
        },
      );

      test(
        '4. Data cuaca tanpa nama kota (cityName == null) menghasilkan respons valid',
        () async {
          fixture.weatherClient.resultToReturn = WeatherResult.success(
            const WeatherData(
              description: 'hujan ringan',
              temperature: 25.6,
              cityName: null,
            ),
          );

          await fixture.startAndConfirmListening();
          await fixture.emitCommandAndComplete('cuaca');

          expect(
            fixture.ttsService.lastSpokenResponse,
            'Cuaca saat ini hujan ringan dengan suhu 26 derajat Celsius.',
          );
          expect(fixture.controller.state, VoiceInteractionState.idle);
        },
      );
    });

    group('Uji Kegagalan Layanan Lokasi pada Alur Cuaca (Location Failure Scenarios)', () {
      test('1. Izin lokasi ditolak (permission denied)', () async {
        fixture.locationClient.checkPermissionValue = LocationPermission.denied;
        fixture.locationClient.requestPermissionValue = LocationPermission.denied;

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(fixture.locationClient.getPositionCallCount, 0);
        expect(fixture.weatherClient.callCount, 0);
        expect(
          fixture.ttsService.lastSpokenResponse,
          LocationPermissionMessages.denied,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('2. Izin lokasi ditolak permanen (deniedForever)', () async {
        fixture.locationClient.checkPermissionValue =
            LocationPermission.deniedForever;

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(fixture.locationClient.requestCallCount, 0);
        expect(fixture.locationClient.getPositionCallCount, 0);
        expect(fixture.weatherClient.callCount, 0);
        expect(
          fixture.ttsService.lastSpokenResponse,
          LocationPermissionMessages.deniedForever,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('3. Layanan GPS / lokasi nonaktif (serviceDisabled)', () async {
        fixture.locationClient.serviceEnabled = false;

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(fixture.locationClient.getPositionCallCount, 0);
        expect(fixture.weatherClient.callCount, 0);
        expect(
          fixture.ttsService.lastSpokenResponse,
          LocationPermissionMessages.serviceDisabled,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('4. Batas waktu pengambilan koordinat habis (timeout)', () async {
        fixture.locationClient.throwTimeout = true;

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(fixture.weatherClient.callCount, 0);
        expect(
          fixture.ttsService.lastSpokenResponse,
          LocationMessages.timeout,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('5. Kegagalan pengambilan posisi dari platform geolocator (failure)', () async {
        fixture.locationClient.throwOnGetPosition = true;

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(fixture.weatherClient.callCount, 0);
        expect(
          fixture.ttsService.lastSpokenResponse,
          contains(LocationMessages.failure),
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });
    });

    group('Uji Kegagalan Layanan Cuaca & Jaringan (Weather & Network Failure Scenarios)', () {
      test('1. API cuaca belum dikonfigurasi (unconfigured)', () async {
        fixture.weatherClient.resultToReturn = WeatherResult.unconfigured();

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(fixture.locationClient.getPositionCallCount, 1);
        expect(fixture.weatherClient.callCount, 1);
        expect(
          fixture.ttsService.lastSpokenResponse,
          WeatherMessages.unconfigured,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('2. API key tidak valid / tidak diotorisasi (unauthorized / HTTP 401)', () async {
        fixture.weatherClient.resultToReturn = WeatherResult.unauthorized();

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(
          fixture.ttsService.lastSpokenResponse,
          WeatherMessages.unauthorized,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('3. Batas kuota API terlampaui (rateLimited / HTTP 429)', () async {
        fixture.weatherClient.resultToReturn = WeatherResult.rateLimited();

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(
          fixture.ttsService.lastSpokenResponse,
          WeatherMessages.rateLimited,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('4. Informasi cuaca untuk lokasi tidak ditemukan (notFound / HTTP 404)', () async {
        fixture.weatherClient.resultToReturn = WeatherResult.notFound();

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(
          fixture.ttsService.lastSpokenResponse,
          WeatherMessages.notFound,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('5. Batas waktu koneksi ke layanan cuaca habis (timeout)', () async {
        fixture.weatherClient.resultToReturn = WeatherResult.timeout();

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(
          fixture.ttsService.lastSpokenResponse,
          WeatherMessages.timeout,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('6. Gagal terhubung ke layanan cuaca / network error', () async {
        fixture.weatherClient.resultToReturn = WeatherResult.networkError();

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(
          fixture.ttsService.lastSpokenResponse,
          WeatherMessages.networkError,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('7. Kesalahan server API cuaca (apiError / HTTP 500)', () async {
        fixture.weatherClient.resultToReturn = WeatherResult.apiError();

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(
          fixture.ttsService.lastSpokenResponse,
          WeatherMessages.apiError,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('8. Kegagalan data / format tidak valid (failure)', () async {
        fixture.weatherClient.resultToReturn =
            WeatherResult.failure(WeatherMessages.invalidFormat);

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(
          fixture.ttsService.lastSpokenResponse,
          WeatherMessages.invalidFormat,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('9. Exception tak terduga pada WeatherClient ditangani dengan aman tanpa crash', () async {
        fixture.weatherClient.throwException = true;

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('cuaca');

        expect(
          fixture.ttsService.lastSpokenResponse,
          contains(WeatherMessages.failure),
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });
    });

    group('Uji Pembatalan dan Race Condition (Cancellation & Race Conditions)', () {
      test('1. Pembatalan sesi di tengah pengambilan lokasi menghentikan alur cuaca & TTS', () async {
        fixture.locationClient.delay = const Duration(milliseconds: 100);

        await fixture.startAndConfirmListening();
        fixture.speechClient.emitResult('cuaca');
        fixture.speechClient.emitStatus('done');

        await Future<void>.delayed(const Duration(milliseconds: 20));
        await fixture.controller.cancel();

        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(fixture.weatherClient.callCount, 0);
        expect(fixture.ttsService.lastSpokenResponse, isNull);
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('2. Pembatalan sesi di tengah pemanggilan API cuaca menghentikan TTS', () async {
        fixture.weatherClient.delay = const Duration(milliseconds: 100);

        await fixture.startAndConfirmListening();
        fixture.speechClient.emitResult('cuaca');
        fixture.speechClient.emitStatus('done');

        await Future<void>.delayed(const Duration(milliseconds: 20));
        await fixture.controller.cancel();

        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(fixture.ttsService.lastSpokenResponse, isNull);
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('3. Pembatalan sesi saat TTS membaca cuaca langsung menghentikan playback', () async {
        final ttsCompleter = Completer<TtsPlaybackResult>();
        fixture.ttsService.pendingResponse = ttsCompleter;

        await fixture.startAndConfirmListening();
        fixture.speechClient.emitResult('cuaca');
        fixture.speechClient.emitStatus('done');

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(fixture.controller.state, VoiceInteractionState.speaking);

        await fixture.controller.cancel();

        expect(fixture.controller.state, VoiceInteractionState.idle);
        expect(fixture.ttsService.speaking, isFalse);
      });

      test('4. Dispose controller saat proses cuaca asinkron sedang berjalan', () async {
        fixture.weatherClient.delay = const Duration(milliseconds: 100);

        await fixture.startAndConfirmListening();
        fixture.speechClient.emitResult('cuaca');
        fixture.speechClient.emitStatus('done');

        await Future<void>.delayed(const Duration(milliseconds: 20));
        fixture.controller.dispose();

        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(fixture.ttsService.lastSpokenResponse, isNull);
      });

      test('5. Sesi lama yang selesai terlambat tidak memengaruhi sesi baru', () async {
        fixture.weatherClient.delay = const Duration(milliseconds: 80);

        // Sesi 1: Perintah cuaca dengan pemanggilan API yang lambat
        await fixture.startAndConfirmListening();
        fixture.speechClient.emitResult('cuaca');
        fixture.speechClient.emitStatus('done');

        await Future<void>.delayed(const Duration(milliseconds: 20));
        // Pengguna membatalkan sesi 1
        await fixture.controller.cancel();

        // Sesi 2: Pengguna menanyakan waktu
        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('jam berapa');

        expect(
          fixture.ttsService.lastSpokenResponse,
          contains('pukul'),
        );

        // Tunggu hingga operasi cuaca sesi 1 yang tertunda selesai
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Pastikan respon cuaca sesi 1 tidak menimpa respon sesi 2
        expect(
          fixture.ttsService.lastSpokenResponse,
          contains('pukul'),
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });
    });

    group('Uji Isolasi Perintah Lain (Command Isolation)', () {
      test('Perintah non-cuaca (day, date, time, unknown) bekerja normal tanpa interferensi cuaca', () async {
        // 1. day
        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('hari ini');
        expect(fixture.ttsService.lastSpokenResponse, 'Hari ini hari Sabtu.');

        // 2. date
        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('tanggal berapa');
        expect(fixture.ttsService.lastSpokenResponse, 'Hari ini tanggal 24 Oktober 2026.');

        // 3. time
        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('jam berapa');
        expect(fixture.ttsService.lastSpokenResponse, contains('pukul 10 pagi'));

        // 4. unknown
        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('putar musik pop');
        expect(
          fixture.ttsService.lastSpokenResponse,
          VoiceController.unsupportedCommandResponse,
        );

        // Pastikan tidak ada pemanggilan ke WeatherClient untuk command non-cuaca
        expect(fixture.weatherClient.callCount, 0);
        expect(fixture.locationClient.getPositionCallCount, 0);
      });
    });
  });
}
